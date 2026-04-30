class DispensacionesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_dispensador_o_admin, except: [:index, :show]
  before_action :set_paciente,     only: [:create]
  before_action :set_paciente_opt, only: [:index]
  before_action :set_dispensacion, only: [:show, :update, :destroy]

  # GET /pacientes/:paciente_id/dispensaciones  OR  GET /dispensaciones?fecha=YYYY-MM-DD
  def index
    if @paciente
      @dispensaciones = @paciente.dispensaciones
                                 .includes(:user, :indicacion_medica, :sede, stock: :lote)
                                 .recientes
    else
      require_dispensador_o_admin
      return if performed?
      fecha = params[:fecha].present? ? Date.parse(params[:fecha]) : Date.today
      @dispensaciones = Dispensacion
        .joins(stock: :sede)
        .where(sedes: { club_id: current_user.club_id })
        .where(fecha_dispensacion: fecha)
        .includes(:user, :paciente, :sede, stock: :lote)
        .order(created_at: :desc)
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

    if @dispensacion.stock && @dispensacion.aporte_socio_ars.nil?
      precio = @dispensacion.stock.precio_sugerido_ars.to_d
      @dispensacion.aporte_socio_ars    = (precio * @dispensacion.cantidad.to_d).round(2)
      @dispensacion.precio_unitario_ars ||= precio
    end

    ActiveRecord::Base.transaction do
      @dispensacion.save!
      crear_movimiento_contable(@dispensacion)
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

  # DELETE /dispensaciones/:id
  def destroy
    @dispensacion.destroy
    head :no_content
  end

  private

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
    @dispensacion = Dispensacion.joins(:stock).where(stocks: { sede_id: current_user.club.sede_ids })
                                .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Dispensación no encontrada' }, status: :not_found
  end

  def dispensacion_params
    params.require(:dispensacion).permit(
      :indicacion_medica_id, :stock_id, :sede_id,
      :cantidad, :precio_unitario_ars, :aporte_socio_ars,
      :observaciones, :fecha_dispensacion, :medio_pago
    )
  end

  def dispensacion_params_update
    params.require(:dispensacion).permit(
      :indicacion_medica_id, :stock_id, :sede_id,
      :aporte_socio_ars, :observaciones, :fecha_dispensacion, :medio_pago
    )
  end

  def require_dispensador_o_admin
    unless current_user.admin? || current_user.medico? || current_user.dispensador?
      render json: { error: 'No autorizado' }, status: :forbidden
    end
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

  def serialize_dispensacion(d)
    stk = d.stock
    {
      id:             d.id,
      club_id:        d.sede&.club_id,
      paciente_id:    d.paciente_id,
      paciente_nombre: "#{d.paciente.nombre} #{d.paciente.apellido}",
      usuario: { id: d.user.id, nombre: d.user.first_name || d.user.email },
      sede: d.sede ? { id: d.sede.id, nombre: d.sede.nombre } : nil,
      stock: stk ? {
        id:                  stk.id,
        forma_producto:      stk.forma_producto,
        unidad:              stk.unidad,
        precio_sugerido_ars: stk.precio_sugerido_ars&.to_f,
        regulatorio:         stk.regulatorio?,
        lote: stk.lote ? { id: stk.lote.id, codigo: stk.lote.codigo } : nil,
      } : nil,
      cantidad:            d.cantidad.to_f,
      precio_unitario_ars: d.precio_unitario_ars&.to_f,
      aporte_socio_ars:    d.aporte_socio_ars&.to_f,
      observaciones:       d.observaciones,
      fecha_dispensacion:  d.fecha_dispensacion,
      medio_pago:          d.medio_pago,
      tiene_movimiento_contable: d.movimiento_contable.present?,
      created_at:          d.created_at,
    }
  end
end
