class ReservasController < ApplicationController
  include DispensacionesFinancieras

  before_action :authenticate_user!

  before_action -> { require_feature!(:produccion_dispensa) }
  before_action :require_reservas_role!
  before_action :set_paciente,     only: [:create]
  before_action :set_paciente_opt, only: [:index]
  before_action :set_reserva,      only: [:show, :update, :destroy, :entregar, :cancelar, :anular_sena]
  # El dashboard cachea sus métricas 10 min; al tocar una reserva lo invalidamos para
  # que la sección "Reservas para preparar" se actualice al instante.
  after_action :bust_dashboard_cache, only: [:create, :update, :destroy, :entregar, :cancelar, :anular_sena]

  # GET /pacientes/:paciente_id/reservas  OR  GET /reservas[?estado=pendiente]
  def index
    scope = if @paciente
      @paciente.reservas
    else
      # Las reservas que se ven son las del stock de las SEDES ASIGNADAS: quien atiende una
      # sede no gestiona las reservas de otra. `club_sede_ids` traía todas las del club.
      Reserva.joins(:stock)
             .where("stocks.sede_id IN (?) OR (stocks.sede_id IS NULL AND stocks.club_id = ?)",
                    current_user.sedes_visibles_ids, current_user.club_id)
    end
    scope = scope.where(estado: params[:estado]) if params[:estado].present?
    scope = scope.includes(:user, { stock: [:genetica, :sede, { lote: :genetica }] }, { items: { stock: [:genetica, { lote: :genetica }] } }, paciente: :cuenta_corriente).recientes
    render json: { reservas: scope.map { |r| serialize_reserva(r) } }
  end

  # GET /reservas/:id
  def show
    render json: serialize_reserva(@reserva)
  end

  # POST /pacientes/:paciente_id/reservas
  def create
    lineas = lineas_param
    if lineas.empty?
      return render json: { errors: ['Agregá al menos un producto a la reserva'] }, status: :unprocessable_entity
    end

    stocks = stocks_visibles(lineas.map { |l| l[:stock_id] })
    faltan = lineas.map { |l| l[:stock_id].to_i } - stocks.keys
    if faltan.any?
      return render json: { errors: ['Stock no encontrado'] }, status: :unprocessable_entity
    end

    reserva = @paciente.reservas.new(reserva_params.except(:stock_id, :cantidad))
    reserva.club  = current_user.club
    reserva.user  = current_user
    # El precio de cada línea es el sugerido del stock con el descuento del paciente, como en la
    # dispensa; el aporte estimado de la reserva es la suma, salvo que lo manden a mano.
    lineas.each do |ln|
      st = stocks[ln[:stock_id].to_i]
      reserva.items.build(stock: st, cantidad: ln[:cantidad].to_d,
                          precio_unitario_ars: precio_linea(st, @paciente))
    end
    reserva.aporte_estimado_ars ||= reserva.items.sum(&:subtotal_ars).round(2)

    if reserva.sena_ars.to_d > reserva.aporte_estimado_ars.to_d
      return render json: { errors: ['La seña no puede superar el total estimado'] }, status: :unprocessable_entity
    end

    ActiveRecord::Base.transaction do
      reserva.save!
      registrar_sena(reserva) if reserva.sena_ars.to_d > 0
    end
    render json: serialize_reserva(reserva), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # PATCH /reservas/:id  — editar una reserva pendiente
  def update
    unless @reserva.pendiente?
      return render json: { error: 'Solo se pueden editar reservas pendientes.' }, status: :unprocessable_entity
    end
    attrs = reserva_update_params
    # Cantidad por línea. `cantidad` a secas sigue valiendo para la reserva de UNA línea (el
    # modelo lo traduce); con varias, hay que decir de cuál.
    lineas_edit = Array(params.dig(:reserva, :items)).map { |l| l.permit(:id, :cantidad) }
    if lineas_edit.empty? && attrs[:cantidad].present?
      if @reserva.items.size > 1
        return render json: { errors: ['La reserva tiene varios productos: indicá la cantidad de cada uno.'] },
                      status: :unprocessable_entity
      end
      lineas_edit = [{ id: @reserva.items.first&.id, cantidad: attrs[:cantidad] }]
    end
    attrs = attrs.except(:cantidad)

    lineas_edit.each do |ln|
      item = @reserva.items.to_a.find { |it| it.id == ln[:id].to_i }
      next unless item
      nueva = ln[:cantidad].to_d
      # El mismo techo que al crearla (`Reserva#stock_disponible`): depósito libre + mesa libre.
      # Sin el término de la mesa, agrandar una reserva de algo que está arriba se rechazaba
      # contra un depósito que ya no la cuenta. Se le devuelve además su propio bloqueo actual.
      st = item.stock
      if st.nil?
        return render json: { errors: ['Ese producto ya no existe.'] }, status: :unprocessable_entity
      end
      disponible = st.cantidad_disponible_real.to_d + st.libre_en_mostrador(st.sede_id) + item.cantidad.to_d
      if nueva <= 0 || nueva > disponible
        return render json: { errors: ["Cantidad inválida para «#{st.etiqueta}». Disponible: #{disponible.to_f}#{st.unidad}"] }, status: :unprocessable_entity
      end
      item.cantidad = nueva
    end
    # Si cambian cantidades, el total estimado se recalcula con los precios de cada línea — salvo
    # que la reserva lo tenga escrito a mano, que no se pisa.
    if lineas_edit.any? && @reserva.items.any?(&:cantidad_changed?) && !attrs.key?(:aporte_estimado_ars)
      @reserva.aporte_estimado_ars = @reserva.items.sum(&:subtotal_ars).round(2) if @reserva.items.all? { |it| it.precio_unitario_ars.present? }
    end
    # La seña no puede superar el total estimado.
    nueva_sena = attrs[:sena_ars].present? ? attrs[:sena_ars].to_d : @reserva.sena_ars.to_d
    total_est  = attrs[:aporte_estimado_ars].present? ? attrs[:aporte_estimado_ars].to_d : @reserva.aporte_estimado_ars.to_d
    if nueva_sena > total_est
      return render json: { errors: ['La seña no puede superar el total estimado.'] }, status: :unprocessable_entity
    end

    sena_anterior  = @reserva.sena_ars.to_d
    medio_anterior = @reserva.medio_pago
    if @reserva.update(attrs)
      # Si cambió la seña (monto o medio), re-registramos su asiento contable: revierte
      # el viejo (y su crédito de cuenta corriente) y crea el nuevo.
      if @reserva.sena_ars.to_d != sena_anterior || @reserva.medio_pago != medio_anterior
        re_registrar_sena!(@reserva)
      end
      render json: serialize_reserva(@reserva)
    else
      render json: { errors: @reserva.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /reservas/:id  — eliminar (solo si nunca se concretó ni tiene seña)
  def destroy
    if @reserva.estado == 'entregada'
      return render json: { error: 'No se puede eliminar una reserva ya entregada.' }, status: :unprocessable_entity
    end
    if @reserva.sena_ars.to_d > 0
      return render json: { error: 'La reserva tiene una seña registrada. Usá "Cancelar" en lugar de eliminar.' }, status: :unprocessable_entity
    end
    @reserva.destroy!
    head :no_content
  end

  # PATCH /reservas/:id/entregar
  # Convierte la reserva en una Dispensacion real. Acá se definen los datos de
  # despacho (delivery/dirección) — no en el alta de la reserva. Re-valida stock/
  # crédito/REPROCANN vía Dispensacion y cobra el RESTO (total − seña).
  def entregar
    unless @reserva.pendiente?
      return render json: { error: "La reserva no está pendiente (#{@reserva.estado})" }, status: :unprocessable_entity
    end

    paciente  = @reserva.paciente
    # Se puede ajustar al entregar: cantidad real entregada por línea y monto a cobrar (el RESTO,
    # total − seña). El cobro de ese resto usa el motor nuevo de cobros.
    #
    # `cantidad` a secas sigue valiendo para la reserva de una línea; con varias van `items`.
    cantidades = Array(params[:items]).to_h { |l| [l[:id].to_i, l[:cantidad]] }
    if cantidades.empty? && params[:cantidad].present? && @reserva.items.size == 1
      cantidades = { @reserva.items.first.id => params[:cantidad] }
    end
    aporte    = params[:aporte_socio_ars].presence ? params[:aporte_socio_ars].to_d : @reserva.aporte_restante_ars
    con_envio = ActiveModel::Type::Boolean.new.cast(params[:con_envio]) == true
    cobrar_en_entrega = ActiveModel::Type::Boolean.new.cast(params[:cobrar_en_entrega]) || false

    dispensacion = paciente.dispensaciones.build(
      sede_id:                @reserva.stock&.sede_id,
      # El medio con el que se seña la reserva es el que se espera al entregarla. Acá había un
      # placeholder 'mixto' "que los cobros afinan": cuando no hay cobros que afinar —el resto
      # es cero porque la seña cubrió todo, o se cobra contra entrega— el placeholder quedaba
      # como valor final y la entrega figuraba como pago mixto sin ningún pago.
      medio_pago:             @reserva.medio_pago.presence || 'efectivo',
      aporte_socio_ars:       aporte,
      descuento_paciente_pct: paciente.descuento_porcentaje.to_d.clamp(0, 100),
      fecha_dispensacion:     Date.current,
      con_envio:              con_envio,
      cobrar_en_entrega:      cobrar_en_entrega,
      observaciones:          "Entrega de reserva ##{@reserva.id}",
    )
    # Una línea de dispensa por línea de reserva: el modelo espeja stock/cantidad en la fila
    # (`sincronizar_mirror_desde_items`) y valida cada una contra su stock.
    @reserva.items.each do |it|
      cant = cantidades.key?(it.id) ? cantidades[it.id].to_d : it.cantidad.to_d
      next if cant <= 0
      dispensacion.items.build(stock: it.stock, cantidad: cant, precio_unitario_ars: it.precio_unitario_ars)
    end
    dispensacion.precio_unitario_ars = dispensacion.items.first&.precio_unitario_ars
    if dispensacion.items.empty?
      return render json: { errors: ['No queda nada para entregar: todas las líneas están en cero.'] }, status: :unprocessable_entity
    end
    dispensacion.user = current_user
    # Lo reservado ya está apartado a nombre del paciente: no pasa por la mesa del mostrador.
    dispensacion.desde_reserva = true

    if con_envio
      dispensacion.delivery_id       = params[:delivery_id]
      dispensacion.contacto_nombre   = params[:contacto_nombre].presence
      dispensacion.contacto_telefono = params[:contacto_telefono].presence
      # La misma regla que la dispensa con envío: la dirección que eligió la pantalla.
      begin
        Envios::DireccionDeEntrega.aplicar(dispensacion, paciente: paciente, params: params)
      rescue Envios::DireccionDeEntrega::Error => e
        return render json: { errors: [e.message] }, status: :unprocessable_entity
      end
    end

    begin
      ActiveRecord::Base.transaction do
        # Liberamos primero el bloqueo de esta reserva para que la dispensación no choque
        # con su propio stock apartado en la validación stock_disponible.
        @reserva.update!(estado: 'entregada', entregada_at: Time.current)
        dispensacion.save! # corre validaciones on:create (stock/REPROCANN) + callbacks
        # Cobro del resto con el motor nuevo (efectivo/transf/cuenta + contra-entrega).
        # Si es contra-entrega, el delivery lo cobra al entregar.
        # Con contra entrega, lo que venga se cobra ahora y el resto queda para el repartidor.
        aplicar_lineas_cobro!(dispensacion, cobros_param, 'creacion', dejar_saldo: cobrar_en_entrega) if cobros_param.present? || !cobrar_en_entrega
        afinar_medio_pago!(dispensacion)
        @reserva.update!(dispensacion: dispensacion)
      end
    rescue ActiveRecord::RecordInvalid => e
      return render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
    rescue => e
      return render json: { errors: [e.message] }, status: :unprocessable_entity
    end
    render json: serialize_reserva(@reserva.reload)
  end

  # PATCH /reservas/:id/cancelar
  def cancelar
    unless @reserva.pendiente?
      return render json: { error: "La reserva no está pendiente (#{@reserva.estado})" }, status: :unprocessable_entity
    end
    @reserva.cancelar!(motivo: params[:motivo])
    render json: serialize_reserva(@reserva)
  end

  # PATCH /reservas/:id/anular_sena
  # Anula la seña: revierte su asiento contable y, con él, el crédito de cuenta
  # corriente que había generado, dejando la reserva en sena_ars = 0. A diferencia
  # de "cancelar" (que conserva la seña como ingreso no reembolsable), esto la borra
  # del libro — es la acción consciente para "devolver/eliminar" una seña.
  def anular_sena
    if @reserva.sena_ars.to_d <= 0
      return render json: { error: 'Esta reserva no tiene seña para anular.' }, status: :unprocessable_entity
    end
    begin
      ActiveRecord::Base.transaction do
        MovimientoContable
          .where(paciente_id: @reserva.paciente_id, categoria: 'aporte_socio')
          .where('descripcion LIKE ?', "Seña reserva ##{@reserva.id} —%")
          .each(&:destroy!)   # callback revierte el crédito de CC; si el período está cerrado, levanta
        @reserva.update!(sena_ars: 0)
      end
    rescue ActiveRecord::RecordNotDestroyed
      return render json: {
        error: 'La seña pertenece a un período contable cerrado y no se puede anular automáticamente. Reabrí el período o registrá un ajuste manual.'
      }, status: :unprocessable_entity
    rescue => e
      return render json: { error: e.message }, status: :unprocessable_entity
    end
    render json: serialize_reserva(@reserva.reload)
  end

  private

  def club_sede_ids = current_user.club.sede_ids

  # Invalida el cache del dashboard del día para este club (analytics dispensador).
  def bust_dashboard_cache
    Rails.cache.delete("analytics/dispensador/#{current_user.club_id}/#{Time.zone.today}")
  end

  def set_paciente
    @paciente = current_user.club.pacientes.find(params[:paciente_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Paciente no encontrado' }, status: :not_found
  end

  def set_paciente_opt
    return unless params[:paciente_id].present?
    @paciente = current_user.club.pacientes.find(params[:paciente_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Paciente no encontrado' }, status: :not_found
  end

  def set_reserva
    @reserva = Reserva.joins(:stock)
      .where("stocks.sede_id IN (?) OR stocks.club_id = ?", club_sede_ids, current_user.club_id)
      .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Reserva no encontrada' }, status: :not_found
  end

  def reserva_params
    params.require(:reserva).permit(
      :stock_id, :cantidad, :fecha_entrega_estimada, :sena_ars,
      :aporte_estimado_ars, :medio_pago, :notas,
      :con_envio, :direccion_envio, :contacto_nombre, :contacto_telefono
    )
  end

  # Las líneas del carrito (`items: [{stock_id, cantidad}]`). `stock_id` + `cantidad` sueltos
  # siguen valiendo como una reserva de una línea, para quien no se enteró del carrito.
  def lineas_param
    lineas = Array(params.dig(:reserva, :items)).map { |l| l.permit(:stock_id, :cantidad).to_h.symbolize_keys }
    if lineas.empty? && reserva_params[:stock_id].present?
      lineas = [{ stock_id: reserva_params[:stock_id], cantidad: reserva_params[:cantidad] }]
    end
    lineas.select { |l| l[:stock_id].present? && l[:cantidad].to_d > 0 }
  end

  # Los stocks pedidos que esta persona puede ver, por id. Un id que no aparece es de otra
  # organización o de una sede que no atiende, y se rechaza igual que antes.
  def stocks_visibles(ids)
    Stock.where(id: ids.map(&:to_i).uniq)
         .where("stocks.club_id = ? OR stocks.sede_id IN (?)", current_user.club_id, club_sede_ids)
         .index_by(&:id)
  end

  # Mismo cálculo que la dispensación: precio sugerido del stock con descuento del paciente.
  def precio_linea(stock, paciente)
    precio_base = stock.precio_sugerido_ars.to_d
    descuento   = paciente.descuento_porcentaje.to_d.clamp(0, 100) / 100
    (precio_base * (1 - descuento)).round(2)
  end

  # Edición de reserva pendiente. La seña SÍ se puede editar (monto y medio): al cambiarla
  # se re-registra su asiento contable y se ajusta el crédito de cuenta corriente.
  def reserva_update_params
    params.require(:reserva).permit(:cantidad, :fecha_entrega_estimada, :medio_pago, :notas, :sena_ars, :aporte_estimado_ars)
  end

  # Gestionan reservas (crear/editar/cancelar/anular seña): admin y supervisor.
  # El dispensador SOLO las ve y las convierte en dispensa (entregar) — no las crea ni
  # gestiona (espeja lo que el front ya restringe con canGestionarReservas).
  DISPENSADOR_ACCIONES = %w[index show entregar].freeze

  def require_reservas_role!
    role = current_user&.role
    return if %w[admin supervisor].include?(role)
    return if role == 'dispensador' && DISPENSADOR_ACCIONES.include?(action_name)
    render json: { error: 'No autorizado' }, status: :forbidden
  end

  # Al editar la seña (monto o medio) re-registramos su asiento contable: destruye el
  # anterior —lo que revierte el crédito de cuenta corriente que había generado— y crea
  # el nuevo con los valores actualizados. Así libro y crédito quedan sincronizados.
  def re_registrar_sena!(reserva)
    MovimientoContable.where(paciente_id: reserva.paciente_id, categoria: 'aporte_socio')
                      .where('descripcion LIKE ?', "Seña reserva ##{reserva.id} —%")
                      .destroy_all   # corre el callback que revierte el crédito de CC
    registrar_sena(reserva) if reserva.sena_ars.to_d > 0
  end

  # La seña es plata real que entra al reservar. Se asienta como ingreso (no reembolsable
  # si la reserva se cancela/vence). Al entregar, la dispensación cobra sólo el resto.
  def registrar_sena(reserva)
    MovimientoContable.create!(
      club:             current_user.club,
      sede_id:          reserva.stock&.sede_id || club_sede_ids.first,
      paciente_id:      reserva.paciente_id,
      created_by:       current_user,
      tipo:             'ingreso',
      categoria:        'aporte_socio',
      descripcion:      "Seña reserva ##{reserva.id} — #{reserva.paciente.nombre} #{reserva.paciente.apellido}",
      monto_ars:        reserva.sena_ars,
      fecha:            Date.current,
      pagado:           true,
      medio_pago:       reserva.medio_pago.presence || 'efectivo',
      comprobante_tipo: 'sin_comprobante',
    )
  end

  def serialize_reserva(r)
    {
      id:                     r.id,
      estado:                 r.estado,
      cantidad:               r.cantidad.to_f,
      fecha_entrega_estimada: r.fecha_entrega_estimada,
      sena_ars:               r.sena_ars.to_f,
      aporte_estimado_ars:    r.aporte_estimado_ars&.to_f,
      aporte_restante_ars:    r.aporte_restante_ars.to_f,
      medio_pago:             r.medio_pago,
      con_envio:              r.con_envio,
      direccion_envio:        r.direccion_envio,
      contacto_nombre:        r.contacto_nombre,
      contacto_telefono:      r.contacto_telefono,
      notas:                  r.notas,
      dispensacion_id:        r.dispensacion_id,
      created_at:             r.created_at,
      entregada_at:           r.entregada_at,
      cancelada_at:           r.cancelada_at,
      vencida_at:             r.vencida_at,
      paciente: r.paciente && {
        id:             r.paciente.id,
        nombre:         r.paciente.nombre_completo,
        dni:            r.paciente.dni,
        saldo_cc:       r.paciente.cuenta_corriente&.saldo_disponible&.to_f,
        limite_cc:      r.paciente.cuenta_corriente&.limite_credito&.to_f,
        tiene_domicilio: r.paciente.domicilio_calle.present?,
      },
      stock: r.stock && {
        id:             r.stock.id,
        forma_producto: r.stock.forma_producto,
        unidad:         r.stock.unidad,
        # QUÉ ES lo que está apartado. «5 g · Flor seca» no alcanza para prepararlo: la variedad
        # es lo que dice cuál de los frascos hay que agarrar, y es lo primero que pregunta el
        # paciente cuando lo viene a buscar.
        genetica:       (r.stock.genetica || r.stock.lote&.genetica)&.nombre,
        lote:           r.stock.lote&.codigo,
        # De qué sede sale lo reservado: quien atiende varias no puede leer una lista donde
        # las reservas de dos mostradores están mezcladas.
        sede:           r.stock.sede && { id: r.stock.sede.id, nombre: r.stock.sede.nombre },
      },
      # Las líneas. `stock` (arriba) es la primera, para los lectores que todavía no las miran.
      items: r.items.map { |it|
        {
          id:                  it.id,
          stock_id:            it.stock_id,
          cantidad:            it.cantidad.to_f,
          precio_unitario_ars: it.precio_unitario_ars&.to_f,
          unidad:              it.stock&.unidad,
          forma_producto:      it.stock&.forma_producto,
          genetica:            it.genetica_nombre || (it.stock&.genetica || it.stock&.lote&.genetica)&.nombre,
          lote:                it.lote_codigo || it.stock&.lote&.codigo,
        }
      },
      reservado_por: r.user && (r.user.first_name || r.user.email),
    }
  end
end
