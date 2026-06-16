class ReservasController < ApplicationController
  include DispensacionesFinancieras

  before_action :authenticate_user!
  before_action :require_reservas_role!
  before_action :set_paciente,     only: [:create]
  before_action :set_paciente_opt, only: [:index]
  before_action :set_reserva,      only: [:show, :entregar, :cancelar]

  # GET /pacientes/:paciente_id/reservas  OR  GET /reservas[?estado=pendiente]
  def index
    scope = if @paciente
      @paciente.reservas
    else
      Reserva.joins(:stock)
             .where("stocks.sede_id IN (?) OR stocks.club_id = ?", club_sede_ids, current_user.club_id)
    end
    scope = scope.where(estado: params[:estado]) if params[:estado].present?
    scope = scope.includes(:paciente, :user, stock: :lote).recientes
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

  # PATCH /reservas/:id/entregar
  # Convierte la reserva en una Dispensacion real: re-valida REPROCANN/crédito/stock
  # (vía las validaciones de Dispensacion) y cobra el RESTO (total − seña).
  def entregar
    unless @reserva.pendiente?
      return render json: { error: "La reserva no está pendiente (#{@reserva.estado})" }, status: :unprocessable_entity
    end

    medio_pago = params[:medio_pago].presence || @reserva.medio_pago.presence || 'efectivo'
    aporte     = @reserva.aporte_restante_ars

    dispensacion = @reserva.paciente.dispensaciones.build(
      stock:             @reserva.stock,
      sede_id:           @reserva.stock&.sede_id,
      cantidad:          @reserva.cantidad,
      medio_pago:        medio_pago,
      aporte_socio_ars:  aporte,
      fecha_dispensacion: Date.current,
      con_envio:          @reserva.con_envio,
      direccion_envio:    @reserva.direccion_envio,
      contacto_nombre:    @reserva.contacto_nombre,
      contacto_telefono:  @reserva.contacto_telefono,
      observaciones:      "Entrega de reserva ##{@reserva.id}",
    )
    dispensacion.user = current_user

    ActiveRecord::Base.transaction do
      # Liberamos primero el bloqueo de esta reserva para que la dispensación no choque
      # con su propio stock apartado en la validación stock_disponible.
      @reserva.update!(estado: 'entregada', entregada_at: Time.current)
      dispensacion.save! # corre validaciones on:create (stock/crédito/REPROCANN) + callbacks
      crear_movimiento_contable(dispensacion)
      debitar_cuenta_corriente(dispensacion) if dispensacion.a_credito?
      debitar_gramos(dispensacion)           if dispensacion.medio_pago == 'credito_gramos'
      @reserva.update!(dispensacion: dispensacion)
    end
    render json: serialize_reserva(@reserva.reload)
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  rescue => e
    render json: { errors: [e.message] }, status: :unprocessable_entity
  end

  # PATCH /reservas/:id/cancelar
  def cancelar
    unless @reserva.pendiente?
      return render json: { error: "La reserva no está pendiente (#{@reserva.estado})" }, status: :unprocessable_entity
    end
    @reserva.cancelar!(motivo: params[:motivo])
    render json: serialize_reserva(@reserva)
  end

  private

  def club_sede_ids = current_user.club.sede_ids

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
      notas:                  r.notas,
      dispensacion_id:        r.dispensacion_id,
      created_at:             r.created_at,
      entregada_at:           r.entregada_at,
      cancelada_at:           r.cancelada_at,
      vencida_at:             r.vencida_at,
      paciente: r.paciente && {
        id:     r.paciente.id,
        nombre: r.paciente.nombre_completo,
        dni:    r.paciente.dni,
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
