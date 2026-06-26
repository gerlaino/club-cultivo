class DispensacionesController < ApplicationController
  include DispensacionesFinancieras

  before_action :authenticate_user!
  before_action :require_dispensaciones_role!
  before_action :require_dispensador_o_admin, except: [:index, :show, :iniciar_viaje, :entregar, :reportar_fallo, :cancelar_entrega, :mis_paquetes, :export_csv]
  before_action :set_paciente,     only: [:create]
  before_action :set_paciente_opt, only: [:index]
  before_action :set_dispensacion, only: [:show, :update, :destroy, :entregar, :reportar_fallo, :reprogramar, :cancelar_entrega]

  # GET /pacientes/:paciente_id/dispensaciones  OR  GET /dispensaciones?fecha=YYYY-MM-DD
  # GET /dispensaciones?con_envio=true[&estado_envio=pendiente][&delivery_id=N][&desde=YYYY-MM-DD][&hasta=YYYY-MM-DD]
  def index
    if @paciente
      base  = @paciente.dispensaciones
                       .includes(:user, :indicacion_medica, :sede, stock: :lote)
                       .recientes
      page  = [params[:pagina].to_i, 1].max
      limit = [[(params[:limite] || 10).to_i, 1].max, 100].min
      @meta = { total: base.count, pagina: page, limite: limit, gramos_totales: base.sum(:cantidad).to_f }
      @dispensaciones = base.offset((page - 1) * limit).limit(limit)
    elsif params[:con_envio] == 'true'
      require_dispensador_o_admin
      return if performed?
      scope = Dispensacion
        .joins(stock: :sede)
        .where(sedes: { club_id: current_user.club_id })
        .where(con_envio: true)
        .includes(:user, :paciente, :sede, :delivery_user, :ruta_entrega, stock: :lote)
      scope = scope.where(estado_envio: params[:estado_envio]) if params[:estado_envio].present?
      scope = scope.where(delivery_id: params[:delivery_id])   if params[:delivery_id].present?
      scope = scope.where("fecha_dispensacion >= ?", Date.parse(params[:desde])) if params[:desde].present?
      scope = scope.where("fecha_dispensacion <= ?", Date.parse(params[:hasta]))  if params[:hasta].present?
      @dispensaciones = scope.order(created_at: :desc)
    else
      require_dispensador_o_admin
      return if performed?
      scope = Dispensacion
        .joins(stock: :sede)
        .where(sedes: { club_id: current_user.club_id })
        .includes(:user, :paciente, :sede, stock: :lote)
      scope = apply_dispensacion_filters(scope)
      if params[:desde].present? || params[:hasta].present?
        desde = params[:desde].present? ? Date.parse(params[:desde]) : nil
        hasta = params[:hasta].present? ? Date.parse(params[:hasta]) : Date.today
        scope = scope.where("fecha_dispensacion >= ?", desde) if desde
        scope = scope.where("fecha_dispensacion <= ?", hasta)
        @dispensaciones = scope.order(fecha_dispensacion: :desc, created_at: :desc)
      else
        fecha = params[:fecha].present? ? Date.parse(params[:fecha]) : Date.today
        @dispensaciones = scope.where(fecha_dispensacion: fecha).order(created_at: :desc)
      end
    end

    payload = { dispensaciones: @dispensaciones.map { |d| serialize_dispensacion(d) } }
    payload[:meta] = @meta if @meta
    render json: payload
  rescue ArgumentError
    render json: { error: 'Fecha inválida' }, status: :unprocessable_entity
  end

  # GET /dispensaciones/:id
  def show
    render json: serialize_dispensacion(@dispensacion)
  end

  # POST /pacientes/:paciente_id/dispensaciones
  def create
    @dispensacion      = @paciente.dispensaciones.build(dispensacion_params)
    @dispensacion.user = current_user
    @dispensacion.sede_id ||= @dispensacion.stock&.sede_id

    # Dirección de entrega: si se pidió usar el domicilio del paciente (o no se cargó
    # ninguna calle), tomamos el domicilio registrado del paciente como snapshot.
    if @dispensacion.con_envio
      usar_domicilio = ActiveModel::Type::Boolean.new.cast(params.dig(:dispensacion, :usar_domicilio_paciente))
      if usar_domicilio || @dispensacion.envio_calle.blank?
        dir = @paciente.direccion_entrega
        @dispensacion.envio_calle  = dir[:calle]
        @dispensacion.envio_altura = dir[:altura]
        @dispensacion.envio_piso   = dir[:piso]
        @dispensacion.envio_depto  = dir[:depto]
        @dispensacion.envio_barrio = dir[:barrio]
        @dispensacion.envio_ciudad = dir[:ciudad]
      end
      @dispensacion.contacto_nombre   ||= @paciente.nombre_completo
      @dispensacion.contacto_telefono ||= @paciente.telefono
    end

    # ── Descuentos: dos distintos, aditivos con tope 100% ──
    #   descuento_paciente_pct: de la ficha del socio (autoritativo desde el server, privado).
    #   descuento_dispensa_pct: puntual que otorga quien dispensa (lo manda el modal).
    desc_paciente = @paciente.descuento_porcentaje.to_d.clamp(0, 100)
    desc_dispensa = params.dig(:dispensacion, :descuento_dispensa_pct).to_d.clamp(0, 100)
    desc_total    = [desc_paciente + desc_dispensa, 100].min
    @dispensacion.descuento_paciente_pct = desc_paciente
    @dispensacion.descuento_dispensa_pct = desc_dispensa

    # El total lo calcula el server. Solo admin/supervisor pueden pisarlo a mano (override).
    override_admin = (current_user.admin? || current_user.supervisor?) && @dispensacion.aporte_socio_ars.to_d > 0
    cantidad       = @dispensacion.cantidad.to_d
    precio_unit_base = @dispensacion.stock&.precio_sugerido_ars.to_d

    if precio_unit_base > 0
      precio_unit_desc = (precio_unit_base * (1 - desc_total / 100)).round(2)
      @dispensacion.precio_unitario_ars = precio_unit_desc
      @dispensacion.aporte_socio_ars    = override_admin ? @dispensacion.aporte_socio_ars : (precio_unit_desc * cantidad).round(2)
    elsif override_admin && cantidad > 0
      # Stock sin precio configurado: admin fija el total a mano.
      @dispensacion.precio_unitario_ars ||= (@dispensacion.aporte_socio_ars.to_d / cantidad).round(2)
    end

    @dispensacion.cobrar_en_entrega = ActiveModel::Type::Boolean.new.cast(params.dig(:dispensacion, :cobrar_en_entrega)) || false
    lineas_cobro = cobros_param
    usa_cobros   = @dispensacion.cobrar_en_entrega || lineas_cobro.present?

    cc = @paciente.cuenta_corriente

    # Camino nuevo (cobros) vs legacy (medio_pago único: gramos / no_abona / single).
    if usa_cobros
      # El precio/total ya se calculó arriba; los cobros validan crédito por su cuenta.
      if @dispensacion.aporte_socio_ars.to_d <= 0
        return render json: { error: 'El aporte del socio debe ser mayor a $0. Verificá que el stock tenga precio configurado.' }, status: :unprocessable_entity
      end
      @dispensacion.medio_pago = 'mixto'   # placeholder; se afina según los cobros
      begin
        ActiveRecord::Base.transaction do
          @dispensacion.save!
          aplicar_lineas_cobro!(@dispensacion, lineas_cobro, 'creacion') unless @dispensacion.cobrar_en_entrega
          afinar_medio_pago!(@dispensacion)
        end
      rescue => e
        return render json: { error: e.message }, status: :unprocessable_entity
      end
    else
      if (err = validar_y_calcular_credito(@dispensacion, cc))
        return render json: { error: err }, status: :unprocessable_entity
      end
      ActiveRecord::Base.transaction do
        @dispensacion.save!
        crear_movimiento_contable(@dispensacion)
        debitar_cuenta_corriente(@dispensacion) if @dispensacion.a_credito? && cc
        debitar_gramos(@dispensacion)           if @dispensacion.medio_pago == 'credito_gramos'
      end
    end

    render json: serialize_dispensacion(@dispensacion), status: :created

  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  rescue => e
    render json: { errors: [e.message] }, status: :unprocessable_entity
  end

  # PATCH/PUT /dispensaciones/:id
  def update
    attrs = dispensacion_params_update
    # Cambios sin impacto financiero (fecha, observaciones, sede, delivery…): update directo.
    financiero = (attrs.keys.map(&:to_s) & %w[cantidad stock_id aporte_socio_ars medio_pago]).any?
    unless financiero
      if @dispensacion.update(attrs)
        return render json: serialize_dispensacion(@dispensacion)
      else
        return render json: { errors: @dispensacion.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # Las dispensas con cobros (pagos partidos / contra-entrega) no se editan en monto
    # por la vía legacy —corrompería el desglose de cobros—. Se cancela y se rehace.
    if @dispensacion.usa_cobros?
      return render json: { error: 'Esta dispensación tiene cobros registrados. Para cambiar el monto, cancelala y volvé a crearla.' }, status: :unprocessable_entity
    end

    # Cambio financiero (incl. cantidad): se revierten los efectos actuales (stock,
    # cuenta corriente, gramos, asientos) y se re-aplican con los valores nuevos, todo
    # en una transacción, para no dejar la contabilidad/stock inconsistentes.
    if @dispensacion.movimientos_contables.any?(&:cerrado?)
      return render json: { error: 'La dispensación pertenece a un período contable cerrado y no puede editarse.' }, status: :unprocessable_entity
    end

    cc = @dispensacion.paciente.cuenta_corriente
    begin
      ActiveRecord::Base.transaction do
        # 1) revertir efectos actuales
        revertir_gramos(@dispensacion)
        revertir_cuenta_corriente(@dispensacion)
        CuentaCorrienteMovimiento.where(dispensacion_id: @dispensacion.id).update_all(dispensacion_id: nil)
        @dispensacion.movimientos_contables.destroy_all
        @dispensacion.send(:incrementar_stock)   # devuelve al stock la cantidad vieja
        @dispensacion.stock.reload
        cc&.reload

        # 2) aplicar cambios nuevos
        @dispensacion.assign_attributes(attrs)

        # 3) validar stock disponible con la cantidad nueva
        disp_real = @dispensacion.stock.cantidad_disponible_real.to_d
        if @dispensacion.cantidad.to_d > disp_real
          raise "Stock insuficiente: hay #{disp_real.round(2)}#{@dispensacion.stock.unidad || 'g'} disponibles"
        end

        if (err = validar_y_calcular_credito(@dispensacion, cc))
          raise err
        end

        @dispensacion.save!
        @dispensacion.send(:decrementar_stock)   # descuenta la cantidad nueva
        crear_movimiento_contable(@dispensacion)
        debitar_cuenta_corriente(@dispensacion) if @dispensacion.a_credito? && cc
        debitar_gramos(@dispensacion)           if @dispensacion.medio_pago == 'credito_gramos'
      end
      render json: serialize_dispensacion(@dispensacion)
    rescue ActiveRecord::RecordInvalid => e
      render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
    rescue => e
      render json: { errors: [e.message] }, status: :unprocessable_entity
    end
  end

  # GET /delivery/mis_paquetes
  def mis_paquetes
    @dispensaciones = Dispensacion
      .del_delivery(current_user.id)
      .joins(stock: :sede)
      .where(sedes: { club_id: current_user.club_id })
      .includes(:paciente, :sede, :ruta_entrega, stock: :lote)
      .order(Arel.sql('orden_entrega NULLS LAST, created_at ASC'))
    render json: { dispensaciones: @dispensaciones.map { |d| serialize_dispensacion_delivery(d) } }
  end

  # PATCH /dispensaciones/iniciar_viaje  { ids: [1,2,3] }
  def iniciar_viaje
    ids = params[:ids].to_a.map(&:to_i)
    dispensaciones = Dispensacion
      .del_delivery(current_user.id)
      .joins(stock: :sede)
      .where(sedes: { club_id: current_user.club_id })
      .where(id: ids, estado_envio: 'pendiente')
    updated = dispensaciones.update_all(estado_envio: 'en_viaje')
    dispensaciones.each { |d| NotificacionDeliveryService.new(d).notificar_despacho }
    render json: { updated: updated }
  end

  # PATCH /dispensaciones/:id/entregar
  def entregar
    unless @dispensacion.delivery_id == current_user.id || current_user.admin? || current_user.supervisor?
      return render json: { error: 'No autorizado' }, status: :forbidden
    end
    unless %w[pendiente en_viaje].include?(@dispensacion.estado_envio)
      return render json: { error: 'La dispensación no está en un estado válido para entregar' }, status: :unprocessable_entity
    end
    if (err = error_orden_ruta).present?
      return render json: { error: err }, status: :unprocessable_entity
    end
    begin
      ActiveRecord::Base.transaction do
        # Cobro contra-entrega: el delivery carga los cobros (efectivo/transf/cuenta).
        # Lo que no cubra en efectivo/transf queda a cuenta corriente (si hay cupo).
        # Las legacy (usa_cobros? = false) ya están saldadas y no entran acá.
        if @dispensacion.usa_cobros? || cobros_param.present?
          aplicar_lineas_cobro!(@dispensacion, cobros_param, 'entrega')
          afinar_medio_pago!(@dispensacion)
        end
        @dispensacion.comprobante_entrega.attach(params[:comprobante_entrega]) if params[:comprobante_entrega].present?
        registrar_evento_envio(@dispensacion, 'entregado', motivo: params[:notas_entrega])
        @dispensacion.update!(
          estado_envio:       'entregado',
          notas_entrega:      params[:notas_entrega],
          firma_entrega_data: params[:firma_entrega_data],
          entregado_at:       Time.current,
          historial_envio:    @dispensacion.historial_envio,
        )
      end
    rescue ActiveRecord::RecordInvalid => e
      return render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
    rescue => e
      return render json: { error: e.message }, status: :unprocessable_entity
    end
    NotificacionDeliveryService.new(@dispensacion).notificar_entrega
    render json: serialize_dispensacion_delivery(@dispensacion)
  end

  # PATCH /dispensaciones/:id/reportar_fallo
  def reportar_fallo
    unless @dispensacion.delivery_id == current_user.id || current_user.admin? || current_user.supervisor?
      return render json: { error: 'No autorizado' }, status: :forbidden
    end
    unless %w[pendiente en_viaje].include?(@dispensacion.estado_envio)
      return render json: { error: 'Estado inválido' }, status: :unprocessable_entity
    end
    motivo = params[:motivo_fallo].presence
    return render json: { error: 'El motivo es requerido' }, status: :unprocessable_entity unless motivo
    if (err = error_orden_ruta).present?
      return render json: { error: err }, status: :unprocessable_entity
    end
    registrar_evento_envio(@dispensacion, 'fallido', motivo: motivo)
    @dispensacion.update!(estado_envio: 'fallido', motivo_fallo: motivo, historial_envio: @dispensacion.historial_envio)
    render json: serialize_dispensacion_delivery(@dispensacion)
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # PATCH /dispensaciones/:id/reprogramar
  # Solo admin. Vuelve un paquete fallido a pendiente para un nuevo intento de entrega.
  def reprogramar
    unless current_user.admin?
      return render json: { error: 'No autorizado' }, status: :forbidden
    end
    unless @dispensacion.estado_envio == 'fallido'
      return render json: { error: 'Solo se pueden reprogramar paquetes fallidos' }, status: :unprocessable_entity
    end
    registrar_evento_envio(@dispensacion, 'reprogramado', motivo: params[:motivo])
    @dispensacion.update!(estado_envio: 'pendiente', motivo_fallo: nil, historial_envio: @dispensacion.historial_envio)
    render json: serialize_dispensacion_delivery(@dispensacion)
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # PATCH /dispensaciones/:id/cancelar_entrega
  # Cancela la dispensación CONSERVANDO el registro (estado 'cancelada'): revierte
  # stock, cuenta corriente y asientos contables, y deja el evento en el historial.
  def cancelar_entrega
    unless current_user.admin? || current_user.supervisor?
      return render json: { error: 'No autorizado' }, status: :forbidden
    end
    if @dispensacion.cancelada?
      return render json: { error: 'La dispensación ya está cancelada' }, status: :unprocessable_entity
    end
    if @dispensacion.movimientos_contables.any?(&:cerrado?)
      return render json: { error: 'Pertenece a un período contable cerrado y no puede cancelarse.' }, status: :unprocessable_entity
    end
    motivo = params[:motivo].presence
    cc = @dispensacion.paciente.cuenta_corriente
    ActiveRecord::Base.transaction do
      revertir_gramos(@dispensacion)
      revertir_cuenta_corriente(@dispensacion)
      CuentaCorrienteMovimiento.where(dispensacion_id: @dispensacion.id).update_all(dispensacion_id: nil)
      @dispensacion.movimientos_contables.destroy_all
      @dispensacion.cobros.destroy_all          # los cobros (y sus comprobantes) se van con la cancelación
      @dispensacion.send(:incrementar_stock)   # el producto vuelve al stock
      registrar_evento_envio(@dispensacion, 'cancelado', motivo: motivo)
      @dispensacion.update!(estado_envio: 'cancelada', historial_envio: @dispensacion.historial_envio)
    end
    render json: serialize_dispensacion_delivery(@dispensacion)
  rescue => e
    render json: { errors: [e.message] }, status: :unprocessable_entity
  end

  # GET /dispensaciones/export_csv
  def export_csv
    unless current_user.admin? || current_user.dispensador?
      return render json: { error: 'No autorizado' }, status: :forbidden
    end

    scope = Dispensacion
      .joins(stock: :sede)
      .where(sedes: { club_id: current_user.club_id })
      .includes(:paciente, :user, :sede, stock: :lote)
      .order(fecha_dispensacion: :desc, created_at: :desc)

    scope = apply_dispensacion_filters(scope)

    if params[:desde].present?
      desde = Date.parse(params[:desde]) rescue nil
      scope = scope.where("fecha_dispensacion >= ?", desde) if desde
    end
    if params[:hasta].present?
      hasta = Date.parse(params[:hasta]) rescue nil
      scope = scope.where("fecha_dispensacion <= ?", hasta) if hasta
    end

    require "csv"
    csv_data = CSV.generate(col_sep: ";", encoding: "UTF-8") do |csv|
      csv << [
        "ID", "Fecha", "Paciente", "DNI", "Sede",
        "Forma producto", "Cantidad (g)", "Precio unitario (ARS)", "Aporte socio (ARS)",
        "Medio de pago", "Lote", "Con envío", "Estado envío", "Registrado por"
      ]
      scope.each do |d|
        csv << [
          d.id,
          d.fecha_dispensacion.strftime("%d/%m/%Y"),
          "#{d.paciente.nombre} #{d.paciente.apellido}",
          d.paciente.dni_normalizado,
          d.sede&.nombre,
          d.stock&.forma_producto,
          d.cantidad.to_f,
          d.precio_unitario_ars&.to_f,
          d.aporte_socio_ars&.to_f,
          d.medio_pago,
          d.stock&.lote&.codigo,
          d.con_envio ? "Sí" : "No",
          d.estado_envio,
          d.user&.first_name || d.user&.email,
        ]
      end
    end

    send_data "\xEF\xBB\xBF#{csv_data}",
              filename:    "dispensaciones_#{Date.today}.csv",
              type:        "text/csv; charset=utf-8",
              disposition: "attachment"
  end

  # DELETE /dispensaciones/:id
  def destroy
    # Una dispensación cuyo asiento cae en un período contable cerrado es
    # inmutable: borrarla dejaría el libro congelado inconsistente con el stock
    if @dispensacion.movimientos_contables.any?(&:cerrado?)
      return render json: { error: 'La dispensación pertenece a un período contable cerrado y no puede eliminarse.' }, status: :unprocessable_entity
    end

    ActiveRecord::Base.transaction do
      revertir_gramos(@dispensacion)
      revertir_cuenta_corriente(@dispensacion)
      # Nullify FK references before destroy (prevents FK constraint violation)
      CuentaCorrienteMovimiento.where(dispensacion_id: @dispensacion.id).update_all(dispensacion_id: nil)
      @dispensacion.destroy
    end
    head :no_content
  end

  private

  # La entrega es secuencial: el delivery solo puede cerrar (entregar/fallar) el
  # despacho que es el siguiente sin resolver de su ruta. El admin queda exento
  # (puede corregir cualquier despacho fuera de orden). Devuelve un mensaje de
  # error si NO corresponde tocar este despacho todavía, o nil si está OK.
  def error_orden_ruta
    return nil if current_user.admin?
    return nil if @dispensacion.siguiente_en_ruta?

    sig = Dispensacion.siguiente_de_ruta(@dispensacion)
    nombre = sig&.paciente && "#{sig.paciente.nombre} #{sig.paciente.apellido}".strip
    if nombre.present?
      "Tenés que cerrar primero la parada anterior de la ruta (#{nombre})."
    else
      "Tenés que cerrar primero la parada anterior de la ruta."
    end
  end

  def apply_dispensacion_filters(scope)
    scope = scope.where(paciente_id: params[:paciente_id])          if params[:paciente_id].present?
    scope = scope.where(medio_pago: params[:medio_pago])            if params[:medio_pago].present?
    scope = scope.where(stocks: { forma_producto: params[:forma_producto] }) if params[:forma_producto].present?
    scope = scope.where(sedes: { id: params[:sede_id] })            if params[:sede_id].present?
    scope
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

  def set_dispensacion
    club_sede_ids = current_user.club.sede_ids
    @dispensacion = Dispensacion
      .joins(:stock)
      .where("stocks.sede_id IN (?) OR stocks.club_id = ?", club_sede_ids, current_user.club_id)
      .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Dispensación no encontrada' }, status: :not_found
  end

  def dispensacion_params
    params.require(:dispensacion).permit(
      :indicacion_medica_id, :stock_id, :sede_id,
      :cantidad, :precio_unitario_ars, :aporte_socio_ars,
      :descuento_dispensa_pct,
      :observaciones, :fecha_dispensacion, :medio_pago,
      :con_envio, :delivery_id, :direccion_envio,
      :contacto_nombre, :contacto_telefono, :notas_envio,
      :firma_entrega_data,
      :envio_calle, :envio_altura, :envio_piso, :envio_depto, :envio_barrio, :envio_ciudad
    )
  end

  def dispensacion_params_update
    params.require(:dispensacion).permit(
      :indicacion_medica_id, :stock_id, :sede_id,
      :cantidad, :aporte_socio_ars, :observaciones, :fecha_dispensacion, :medio_pago,
      :delivery_id
    )
  end

  # Agrega un evento a la bitácora de entrega (no guarda: el caller hace update!).
  def registrar_evento_envio(disp, evento, motivo: nil)
    disp.historial_envio = (disp.historial_envio || []) + [{
      'evento'         => evento,
      'fecha'          => Time.current.iso8601,
      'motivo'         => motivo.presence,
      'usuario_id'     => current_user.id,
      'usuario_nombre' => current_user.first_name || current_user.email,
    }]
  end

  # Valida el medio de pago y calcula cuánto cae al crédito (monto_credito_ars).
  # Devuelve un string de error o nil. Compartido entre create y update.
  def validar_y_calcular_credito(dispensacion, cc)
    monto = dispensacion.aporte_socio_ars.to_d
    if monto <= 0 && dispensacion.medio_pago != 'credito_gramos'
      return 'El aporte del socio debe ser mayor a $0. Verificá que el stock tenga precio configurado.'
    end
    credito_disp = cc ? [cc.saldo_disponible.to_d + cc.limite_credito.to_d, 0].max : 0
    dispensacion.monto_credito_ars = 0
    case dispensacion.medio_pago
    when 'cuenta_corriente'
      return 'El paciente no tiene crédito configurado para cobrar por cuenta corriente.' unless cc&.limite_credito.to_f > 0
      dispensacion.monto_credito_ars = [monto, credito_disp].min
    when 'no_abona'
      return 'El paciente no tiene crédito configurado. Consultá con el administrador.' if cc.nil? || cc.limite_credito.to_f <= 0
      return 'Crédito insuficiente para realizar la dispensa.' unless cc.puede_dispensar?(monto)
      dispensacion.monto_credito_ars = monto
    when 'credito_gramos'
      return 'El paciente no tiene crédito en gramos activo.' unless cc&.credito_gramos_activo?
      return "Gramos insuficientes: dispone de #{cc.saldo_disponible_g.to_f}g" if cc.saldo_disponible_g.to_d < dispensacion.cantidad.to_d
    end
    nil
  end

  def require_dispensaciones_role!
    # delivery solo puede acceder a sus propias acciones
    if current_user&.role == 'delivery'
      delivery_actions = %w[mis_paquetes iniciar_viaje entregar reportar_fallo]
      unless delivery_actions.include?(action_name)
        render json: { error: 'No autorizado' }, status: :forbidden
      end
      return
    end
    blocked = %w[auditor abogado cultivador manicura paciente]
    if blocked.include?(current_user&.role)
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end

  def require_dispensador_o_admin
    unless current_user.admin? || current_user.medico? || current_user.dispensador?
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end

  def revertir_cuenta_corriente(dispensacion)
    cc = dispensacion.paciente.cuenta_corriente
    return unless cc

    # Usar la suma real de débitos (más robusto ante el bug de doble POST).
    # Solo débitos en pesos: los de gramos los maneja revertir_gramos.
    total = cc.movimientos.where(dispensacion: dispensacion, tipo: 'debito')
              .where("unidad IS NULL OR unidad = 'ars'")
              .sum(:monto).abs
    return if total <= 0

    anterior = cc.saldo_disponible
    nuevo    = anterior + total
    cc.update!(saldo_disponible: nuevo)
    cc.movimientos.create!(
      tipo:           'ajuste',
      monto:          total,
      saldo_anterior: anterior,
      saldo_nuevo:    nuevo,
      descripcion:    "Reversa dispensación ##{dispensacion.id}",
      created_by:     current_user,
    )
  end

  def revertir_gramos(dispensacion)
    cc = dispensacion.paciente.cuenta_corriente
    return unless cc

    # Busca por unidad='gramos' (nuevos registros) o por descripción como fallback (registros anteriores a la migración)
    total_g = cc.movimientos.where(dispensacion: dispensacion, tipo: 'debito')
                .where("unidad = 'gramos' OR descripcion ILIKE ?", '%(crédito gramos)%')
                .sum(:monto).abs
    return if total_g <= 0

    anterior = cc.saldo_disponible_g.to_d
    nuevo    = anterior + total_g
    cc.update!(saldo_disponible_g: nuevo)
    cc.movimientos.create!(
      tipo:           'ajuste',
      monto:          total_g,
      saldo_anterior: anterior,
      saldo_nuevo:    nuevo,
      descripcion:    "Reversa dispensación ##{dispensacion.id} (gramos)",
      created_by:     current_user,
    )
  end

  def serialize_dispensacion_delivery(d) = DispensacionSerializer.serialize_delivery(d)
  def serialize_dispensacion(d) = DispensacionSerializer.serialize(d)
end
