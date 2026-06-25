class ReservasController < ApplicationController
  include DispensacionesFinancieras

  before_action :authenticate_user!
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
      Reserva.joins(:stock)
             .where("stocks.sede_id IN (?) OR stocks.club_id = ?", club_sede_ids, current_user.club_id)
    end
    scope = scope.where(estado: params[:estado]) if params[:estado].present?
    scope = scope.includes(:user, stock: :lote, paciente: :cuenta_corriente).recientes
    render json: { reservas: scope.map { |r| serialize_reserva(r) } }
  end

  # GET /reservas/:id
  def show
    render json: serialize_reserva(@reserva)
  end

  # POST /pacientes/:paciente_id/reservas
  def create
    stock = Stock.where(id: reserva_params[:stock_id])
                 .where("stocks.club_id = ? OR stocks.sede_id IN (?)", current_user.club_id, club_sede_ids)
                 .first
    unless stock
      return render json: { errors: ['Stock no encontrado'] }, status: :unprocessable_entity
    end

    reserva = @paciente.reservas.new(reserva_params)
    reserva.club  = current_user.club
    reserva.user  = current_user
    reserva.stock = stock
    reserva.aporte_estimado_ars ||= estimar_aporte(stock, @paciente, reserva.cantidad)

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
    # Si cambia la cantidad, re-validar disponibilidad (devolviendo el bloqueo propio actual).
    if attrs[:cantidad].present?
      nueva       = attrs[:cantidad].to_d
      disponible  = @reserva.stock.cantidad_disponible_real.to_d + @reserva.cantidad.to_d
      if nueva <= 0 || nueva > disponible
        return render json: { errors: ["Cantidad inválida. Disponible: #{disponible.to_f}#{@reserva.stock.unidad}"] }, status: :unprocessable_entity
      end
    end
    # La seña no puede superar el total estimado.
    nueva_sena = attrs[:sena_ars].present? ? attrs[:sena_ars].to_d : @reserva.sena_ars.to_d
    if nueva_sena > @reserva.aporte_estimado_ars.to_d
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
    # Se puede ajustar al entregar: cantidad real entregada y monto a cobrar (el RESTO,
    # total − seña). El cobro de ese resto usa el motor nuevo de cobros.
    cantidad  = params[:cantidad].presence ? params[:cantidad].to_d : @reserva.cantidad
    aporte    = params[:aporte_socio_ars].presence ? params[:aporte_socio_ars].to_d : @reserva.aporte_restante_ars
    con_envio = ActiveModel::Type::Boolean.new.cast(params[:con_envio]) == true
    cobrar_en_entrega = ActiveModel::Type::Boolean.new.cast(params[:cobrar_en_entrega]) || false

    dispensacion = paciente.dispensaciones.build(
      stock:                  @reserva.stock,
      sede_id:                @reserva.stock&.sede_id,
      cantidad:               cantidad,
      medio_pago:             'mixto',          # placeholder; los cobros lo afinan
      aporte_socio_ars:       aporte,
      descuento_paciente_pct: paciente.descuento_porcentaje.to_d.clamp(0, 100),
      fecha_dispensacion:     Date.current,
      con_envio:              con_envio,
      cobrar_en_entrega:      cobrar_en_entrega,
      observaciones:          "Entrega de reserva ##{@reserva.id}",
    )
    dispensacion.user = current_user

    if con_envio
      dispensacion.delivery_id = params[:delivery_id]
      usar_domicilio = ActiveModel::Type::Boolean.new.cast(params[:usar_domicilio_paciente])
      if usar_domicilio || params[:envio_calle].blank?
        dir = paciente.direccion_entrega
        dispensacion.envio_calle  = dir[:calle]
        dispensacion.envio_altura = dir[:altura]
        dispensacion.envio_piso   = dir[:piso]
        dispensacion.envio_depto  = dir[:depto]
        dispensacion.envio_barrio = dir[:barrio]
        dispensacion.envio_ciudad = dir[:ciudad]
      else
        dispensacion.envio_calle  = params[:envio_calle]
        dispensacion.envio_altura = params[:envio_altura]
        dispensacion.envio_piso   = params[:envio_piso]
        dispensacion.envio_depto  = params[:envio_depto]
        dispensacion.envio_barrio = params[:envio_barrio]
        dispensacion.envio_ciudad = params[:envio_ciudad]
      end
      dispensacion.contacto_nombre   = params[:contacto_nombre].presence   || paciente.nombre_completo
      dispensacion.contacto_telefono = params[:contacto_telefono].presence || paciente.telefono
    end

    begin
      ActiveRecord::Base.transaction do
        # Liberamos primero el bloqueo de esta reserva para que la dispensación no choque
        # con su propio stock apartado en la validación stock_disponible.
        @reserva.update!(estado: 'entregada', entregada_at: Time.current)
        dispensacion.save! # corre validaciones on:create (stock/REPROCANN) + callbacks
        # Cobro del resto con el motor nuevo (efectivo/transf/cuenta + contra-entrega).
        # Si es contra-entrega, el delivery lo cobra al entregar.
        aplicar_lineas_cobro!(dispensacion, cobros_param, 'creacion') unless cobrar_en_entrega
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
    Rails.cache.delete("analytics/dispensador/#{current_user.club_id}/#{Date.today}")
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

  # Edición de reserva pendiente. La seña SÍ se puede editar (monto y medio): al cambiarla
  # se re-registra su asiento contable y se ajusta el crédito de cuenta corriente.
  def reserva_update_params
    params.require(:reserva).permit(:cantidad, :fecha_entrega_estimada, :medio_pago, :notas, :sena_ars)
  end

  # Reservan: dispensador, admin, supervisor.
  def require_reservas_role!
    return if %w[admin dispensador supervisor].include?(current_user&.role)
    render json: { error: 'No autorizado' }, status: :forbidden
  end

  # Mismo cálculo que la dispensación: precio sugerido del stock con descuento del socio.
  def estimar_aporte(stock, paciente, cantidad)
    precio_base = stock.precio_sugerido_ars.to_d
    descuento   = paciente.descuento_porcentaje.to_d.clamp(0, 100) / 100
    (precio_base * (1 - descuento) * cantidad.to_d).round(2)
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
        lote:           r.stock.lote&.codigo,
      },
      reservado_por: r.user && (r.user.first_name || r.user.email),
    }
  end
end
