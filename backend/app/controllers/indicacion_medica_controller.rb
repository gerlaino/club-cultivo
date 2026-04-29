class IndicacionMedicaController < ApplicationController
  before_action :authenticate_user!
  before_action :require_medico_or_admin, except: [:index, :show]
  before_action :set_paciente, only: [:index, :create]
  before_action :set_indicacion, only: [:show, :update, :destroy]

  # GET /pacientes/:paciente_id/indicaciones
  def index
    indicaciones = @paciente.indicacion_medicas.order(fecha_emision: :desc)
    render json: indicaciones.map { |i| serialize_indicacion(i) }
  end

  # GET /indicaciones/:id
  def show
    render json: serialize_indicacion_detail(@indicacion)
  end

  # POST /pacientes/:paciente_id/indicaciones
  def create
    indicacion = @paciente.indicacion_medicas.build(indicacion_params)
    indicacion.user = current_user

    if indicacion.save
      render json: serialize_indicacion(indicacion), status: :created
    else
      render json: { errors: indicacion.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /indicaciones/:id
  def update
    if @indicacion.update(indicacion_params)
      render json: serialize_indicacion(@indicacion)
    else
      render json: { errors: @indicacion.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /indicaciones/:id
  def destroy
    @indicacion.update(activa: false)
    head :no_content
  end

  private

  def require_medico_or_admin
    unless current_user.admin? || current_user.medico?
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end

  def set_paciente
    @paciente = current_user.club.pacientes.find(params[:paciente_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Paciente no encontrado' }, status: :not_found
  end

  def set_indicacion
    @indicacion = IndicacionMedica.joins(:paciente)
                                  .where(pacientes: { club_id: current_user.club_id })
                                  .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Indicación no encontrada' }, status: :not_found
  end

  def indicacion_params
    params.require(:indicacion_medica).permit(
      :patologia,
      :dosificacion,
      :via_administracion,
      :duracion_dias,
      :fecha_emision,
      :fecha_vencimiento,
      :activa,
      :observaciones
    )
  end

  def serialize_indicacion(indicacion)
    {
      id: indicacion.id,
      patologia: indicacion.patologia,
      dosificacion: indicacion.dosificacion,
      via_administracion: indicacion.via_administracion,
      duracion_dias: indicacion.duracion_dias,
      fecha_emision: indicacion.fecha_emision,
      fecha_vencimiento: indicacion.fecha_vencimiento,
      activa: indicacion.activa,
      dias_hasta_vencimiento: indicacion.dias_hasta_vencimiento,
      vencida: indicacion.vencida?,
      por_vencer: indicacion.por_vencer?,
      medico: {
        id: indicacion.user.id,
        nombre: "#{indicacion.user.first_name} #{indicacion.user.last_name}".strip
      },
      created_at: indicacion.created_at
    }
  end

  def serialize_indicacion_detail(indicacion)
    serialize_indicacion(indicacion).merge(
      observaciones: indicacion.observaciones,
      paciente: {
        id: indicacion.paciente.id,
        nombre_completo: indicacion.paciente.nombre_completo
      }
    )
  end
end