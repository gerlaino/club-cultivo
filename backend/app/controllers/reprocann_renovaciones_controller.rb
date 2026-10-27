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
      # Aprobar es cargar el vencimiento nuevo: sin fecha, la ficha seguiría diciendo «vencido».
      if params[:fecha_vencimiento_nueva].blank?
        return render json: { errors: ['Cargá la fecha de vencimiento nueva.'] }, status: :unprocessable_entity
      end
      @renovacion.aprobar!(
        reprocann_numero_nuevo:  params[:reprocann_numero_nuevo].presence,
        fecha_vencimiento_nueva: params[:fecha_vencimiento_nueva],
        por: current_user,
      )
    when 'rechazar'
      @renovacion.rechazar!(observaciones: params[:observaciones], por: current_user)
    else
      @renovacion.update!(renovacion_params)
    end
    if %w[aprobar rechazar].include?(accion)
      @renovacion.avisar_al_paciente!
      @renovacion.avisar_a_la_organizacion!
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
      origen:                 r.origen,
      constancia_url:         r.constancia.attached? ? url_for(r.constancia) : nil,
      constancia_nombre:      r.constancia.attached? ? r.constancia.filename.to_s : nil,
      reprocann_numero_nuevo: r.reprocann_numero_nuevo,
      observaciones:          r.observaciones,
      iniciada_por:           r.iniciada_por&.nombre_completo,
      created_at:             r.created_at,
    }
  end
end
