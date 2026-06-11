class DispensacionesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_dispensaciones_role!
  before_action :require_dispensador_o_admin, except: [:index, :show, :iniciar_viaje, :entregar, :reportar_fallo, :mis_paquetes, :export_csv]
  before_action :set_paciente,     only: [:create]
  before_action :set_paciente_opt, only: [:index]
  before_action :set_dispensacion, only: [:show, :update, :destroy, :entregar, :reportar_fallo, :reprogramar]

  # GET /pacientes/:paciente_id/dispensaciones  OR  GET /dispensaciones?fecha=YYYY-MM-DD
  # GET /dispensaciones?con_envio=true[&estado_envio=pendiente][&delivery_id=N][&desde=YYYY-MM-DD][&hasta=YYYY-MM-DD]
  def index
    if @paciente
      @dispensaciones = @paciente.dispensaciones
                                 .includes(:user, :indicacion_medica, :sede, stock: :lote)
                                 .recientes
    elsif params[:con_envio] == 'true'
      require_dispensador_o_admin
      return if performed?
      scope = Dispensacion
        .joins(stock: :sede)
        .where(sedes: { club_id: current_user.club_id })
        .where(con_envio: true)
        .includes(:user, :paciente, :sede, :delivery_user, stock: :lote)
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

    render json: { dispensaciones: @dispensaciones.map { |d| serialize_dispensacion(d) } }
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

    needs_autocalc = @dispensacion.aporte_socio_ars.nil? ||
                     (@dispensacion.aporte_socio_ars.to_d <= 0 && @dispensacion.medio_pago == 'no_abona')
    if @dispensacion.stock && needs_autocalc
      precio_base = @dispensacion.stock.precio_sugerido_ars.to_d
      descuento   = @paciente.descuento_porcentaje.to_d.clamp(0, 100) / 100
      precio      = precio_base * (1 - descuento)
      @dispensacion.aporte_socio_ars    = (precio * @dispensacion.cantidad.to_d).round(2)
      @dispensacion.precio_unitario_ars ||= precio
    end

    cc    = @paciente.cuenta_corriente
    monto = @dispensacion.aporte_socio_ars.to_d

    # Validaciones específicas por medio de pago
    case @dispensacion.medio_pago
    when 'cuenta_corriente'
      if monto <= 0
        return render json: { error: 'El aporte del socio debe ser mayor a $0 para cobrar por cuenta corriente.' }, status: :unprocessable_entity
      end
      unless cc&.limite_credito.to_f > 0
        return render json: { error: 'No se puede realizar la dispensa. Sin crédito disponible. Consultá con el administrador.' }, status: :unprocessable_entity
      end
    when 'no_abona'
      if cc.nil? || cc.limite_credito.to_f <= 0
        return render json: { error: 'El paciente no tiene crédito configurado. Consultá con el administrador.' }, status: :unprocessable_entity
      end
      if monto <= 0
        return render json: { error: 'No se puede determinar el valor del producto. Configurá el precio del stock.' }, status: :unprocessable_entity
      end
    end

    # Verificación universal de crédito: si el paciente tiene límite configurado,
    # ninguna dispensación (sea cual sea el medio de pago) puede superar el disponible.
    if cc&.limite_credito.to_f > 0 && monto > 0 && !cc.puede_dispensar?(monto)
      return render json: { error: 'Crédito insuficiente para realizar la dispensa.' }, status: :unprocessable_entity
    end

    ActiveRecord::Base.transaction do
      @dispensacion.save!
      crear_movimiento_contable(@dispensacion)
      # Debitar crédito para todos los medios de pago cuando el paciente tiene límite
      debitar_cuenta_corriente(@dispensacion) if cc&.limite_credito.to_f > 0
    end

    render json: serialize_dispensacion(@dispensacion), status: :created

  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  rescue => e
    render json: { errors: [e.message] }, status: :unprocessable_entity
  end

  # PATCH/PUT /dispensaciones/:id
  def update
    if @dispensacion.update(dispensacion_params_update)
      render json: serialize_dispensacion(@dispensacion)
    else
      render json: { errors: @dispensacion.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /delivery/mis_paquetes
  def mis_paquetes
    @dispensaciones = Dispensacion
      .del_delivery(current_user.id)
      .joins(stock: :sede)
      .where(sedes: { club_id: current_user.club_id })
      .includes(:paciente, :sede, stock: :lote)
      .order(created_at: :asc)
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
    unless @dispensacion.delivery_id == current_user.id || current_user.admin?
      return render json: { error: 'No autorizado' }, status: :forbidden
    end
    unless %w[pendiente en_viaje].include?(@dispensacion.estado_envio)
      return render json: { error: 'La dispensación no está en un estado válido para entregar' }, status: :unprocessable_entity
    end
    @dispensacion.update!(
      estado_envio:       'entregado',
      notas_entrega:      params[:notas_entrega],
      firma_entrega_data: params[:firma_entrega_data],
      entregado_at:       Time.current
    )
    NotificacionDeliveryService.new(@dispensacion).notificar_entrega
    render json: serialize_dispensacion_delivery(@dispensacion)
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # PATCH /dispensaciones/:id/reportar_fallo
  def reportar_fallo
    unless @dispensacion.delivery_id == current_user.id || current_user.admin?
      return render json: { error: 'No autorizado' }, status: :forbidden
    end
    unless %w[pendiente en_viaje].include?(@dispensacion.estado_envio)
      return render json: { error: 'Estado inválido' }, status: :unprocessable_entity
    end
    motivo = params[:motivo_fallo].presence
    return render json: { error: 'El motivo es requerido' }, status: :unprocessable_entity unless motivo
    @dispensacion.update!(estado_envio: 'fallido', motivo_fallo: motivo)
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
    @dispensacion.update!(estado_envio: 'pendiente', motivo_fallo: nil)
    render json: serialize_dispensacion_delivery(@dispensacion)
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
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
    ActiveRecord::Base.transaction do
      revertir_cuenta_corriente(@dispensacion)
      # Nullify FK references before destroy (prevents FK constraint violation)
      CuentaCorrienteMovimiento.where(dispensacion_id: @dispensacion.id).update_all(dispensacion_id: nil)
      @dispensacion.destroy
    end
    head :no_content
  end

  private

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
      :observaciones, :fecha_dispensacion, :medio_pago,
      :con_envio, :delivery_id, :direccion_envio,
      :contacto_nombre, :contacto_telefono, :notas_envio,
      :firma_entrega_data
    )
  end

  def dispensacion_params_update
    params.require(:dispensacion).permit(
      :indicacion_medica_id, :stock_id, :sede_id,
      :aporte_socio_ars, :observaciones, :fecha_dispensacion, :medio_pago,
      :delivery_id
    )
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

  def debitar_cuenta_corriente(dispensacion)
    monto = dispensacion.aporte_socio_ars.to_d
    return if monto <= 0

    cc = dispensacion.paciente.cuenta_corriente
    # Guard: evitar doble débito si la dispensación ya tiene un movimiento registrado
    return if cc.movimientos.exists?(dispensacion: dispensacion, tipo: 'debito')

    anterior = cc.saldo_disponible
    nuevo    = anterior - monto
    cc.update!(saldo_disponible: nuevo)
    cc.movimientos.create!(
      tipo:           'debito',
      unidad:         'ars',
      monto:          -monto,
      saldo_anterior: anterior,
      saldo_nuevo:    nuevo,
      descripcion:    "Dispensación: #{dispensacion.cantidad}#{dispensacion.stock&.unidad} #{dispensacion.stock&.forma_producto}",
      dispensacion:   dispensacion,
      created_by:     current_user,
    )
  end

  def revertir_cuenta_corriente(dispensacion)
    cc = dispensacion.paciente.cuenta_corriente
    return unless cc

    # Usar la suma real de débitos (más robusto ante el bug de doble POST)
    total = cc.movimientos.where(dispensacion: dispensacion, tipo: 'debito').sum(:monto).abs
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

  def debitar_gramos(dispensacion)
    gramos = dispensacion.cantidad.to_d
    return if gramos <= 0

    cc = dispensacion.paciente.cuenta_corriente
    return unless cc&.credito_gramos_activo?
    return if cc.movimientos.exists?(dispensacion: dispensacion, tipo: 'debito')

    anterior = cc.saldo_disponible_g.to_d
    nuevo    = anterior - gramos
    cc.update!(saldo_disponible_g: nuevo)
    cc.movimientos.create!(
      tipo:           'debito',
      unidad:         'gramos',
      monto:          -gramos,
      saldo_anterior: anterior,
      saldo_nuevo:    nuevo,
      descripcion:    "Dispensación #{gramos}g (crédito gramos)",
      dispensacion:   dispensacion,
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

  def crear_movimiento_contable(dispensacion)
    monto = dispensacion.aporte_socio_ars.to_d
    return if monto <= 0

    descripcion = "Dispensación #{dispensacion.cantidad}#{dispensacion.stock&.unidad} " \
      "#{dispensacion.stock&.forma_producto} — " \
      "#{dispensacion.paciente.nombre} #{dispensacion.paciente.apellido}"

    MovimientoContable.create!(
      club:             current_user.club,
      sede_id:          dispensacion.sede_id,
      dispensacion:     dispensacion,
      created_by:       current_user,
      tipo:             'recupero_costo',
      categoria:        'dispensacion',
      descripcion:      descripcion,
      monto_ars:        monto,
      fecha:            dispensacion.fecha_dispensacion,
      pagado:           true,
      medio_pago:       dispensacion.medio_pago || 'efectivo',
      comprobante_tipo: 'sin_comprobante',
    )
  end

  def serialize_dispensacion_delivery(d) = DispensacionSerializer.serialize_delivery(d)
  def serialize_dispensacion(d) = DispensacionSerializer.serialize(d)
end
