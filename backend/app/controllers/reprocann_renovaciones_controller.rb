class ReprocannRenovacionesController < ApplicationController
  before_action :authenticate_user!
  before_action -> { require_feature!(:produccion_dispensa) }
  before_action :set_paciente
  before_action :set_renovacion, only: [:update, :destroy]

  def index
    authorize @paciente, :show?
    renovaciones = @paciente.reprocann_renovaciones.recientes
    render json: { data: renovaciones.map { |r| serialize(r) } }
  end

  def create
    authorize @paciente, :update?
    renovacion = @paciente.reprocann_renovaciones.build(renovacion_params)
    renovacion.club        = current_user.club
    renovacion.iniciada_por = current_user
    renovacion.fecha_inicio = Time.zone.today if renovacion.fecha_inicio.blank?

    if renovacion.save
      render json: { data: serialize(renovacion) }, status: :created
    else
      render json: { errors: renovacion.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    authorize @paciente, :update?
    accion = params[:accion]

    case accion
    when 'aprobar'
      @renovacion.aprobar!(
        reprocann_numero_nuevo:  params[:reprocann_numero_nuevo],
        fecha_vencimiento_nueva: params[:fecha_vencimiento_nueva],
      )
    when 'rechazar'
      @renovacion.rechazar!(observaciones: params[:observaciones])
    else
      @renovacion.update!(renovacion_params)
    end

    render json: { data: serialize(@renovacion) }
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def destroy
    authorize @paciente, :update?
    @renovacion.destroy
    head :no_content
  end

  private

  def set_paciente
    @paciente = policy_scope(Paciente).find(params[:paciente_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Paciente no encontrado' }, status: :not_found
  end

  def set_renovacion
    @renovacion = @paciente.reprocann_renovaciones.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Renovación no encontrada' }, status: :not_found
  end

  def renovacion_params
    params.permit(:estado, :numero_tramite, :fecha_inicio, :fecha_aprobacion,
                  :fecha_vencimiento_nueva, :observaciones, :reprocann_numero_nuevo)
  end

  def serialize(r)
    {
      id:                     r.id,
      estado:                 r.estado,
      numero_tramite:         r.numero_tramite,
      fecha_inicio:           r.fecha_inicio,
      fecha_aprobacion:       r.fecha_aprobacion,
      fecha_vencimiento_nueva: r.fecha_vencimiento_nueva,
      reprocann_numero_nuevo: r.reprocann_numero_nuevo,
      observaciones:          r.observaciones,
      iniciada_por:           r.iniciada_por&.nombre_completo,
      created_at:             r.created_at,
    }
  end
end
