class PlantActivitiesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_plant
  skip_before_action :require_admin_o_agricultor, raise: false

  def index
    activities = @plant.activities
                       .order(occurred_at: :desc)
                       .limit(50)
    render json: activities.map { |a| serialize(a) }
  end

  def create
    activity = @plant.activities.build(
      activity_type: params.dig(:plant_activity, :activity_type),
      description:   params.dig(:plant_activity, :description),
      metadata:      params.dig(:plant_activity, :metadata)&.to_unsafe_h || {},
      user:          current_user,
      occurred_at:   Time.current
    )

    # Actualizar campos denormalizados en la planta
    if activity.activity_type == 'registro_planta' && activity.metadata.present?
      meta = activity.metadata
      @plant.altura_actual = meta['altura_cm']    if meta['altura_cm'].present?
      @plant.num_colas     = meta['num_colas']    if meta['num_colas'].present?
      @plant.estado_salud  = meta['estado_salud'] if meta['estado_salud'].present?
      @plant.color_hojas   = meta['color_hojas']  if meta['color_hojas'].present?
      @plant.save!
    end

    if activity.save
      render json: serialize(activity), status: :created
    else
      render json: { errors: activity.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    activity = @plant.activities.find(params[:id])
    activity.destroy
    head :no_content
  end

  private

  def set_plant
    @plant = Plant.joins(:lote)
                  .where(lotes: { club_id: current_user.club_id })
                  .find(params[:plant_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Planta no encontrada' }, status: :not_found
  end

  def serialize(a)
    {
      id:            a.id,
      activity_type: a.activity_type,
      description:   a.description,
      metadata:      a.metadata,
      occurred_at:   a.occurred_at,
      usuario:       a.user.nombre_completo,
      created_at:    a.created_at
    }
  end
end
