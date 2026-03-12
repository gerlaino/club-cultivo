class PlantActivitiesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_plant

  # GET /plants/:plant_id/activities
  def index
    activities = @plant.activities.recent.includes(:user)

    render json: activities.map { |a| serialize_activity(a) }
  end

  # POST /plants/:plant_id/activities
  def create
    activity = @plant.activities.build(activity_params)
    activity.user = current_user
    activity.occurred_at ||= Time.current

    if activity.save
      render json: serialize_activity(activity), status: :created
    else
      render json: { errors: activity.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /plants/:plant_id/activities/:id
  def destroy
    activity = @plant.activities.find(params[:id])
    activity.destroy
    head :no_content
  end

  private

  def set_plant
    club = current_user.club
    @plant = Plant.joins(:lote).where(lotes: { club_id: club.id }).find(params[:plant_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Planta no encontrada' }, status: :not_found
  end

  def activity_params
    params.require(:plant_activity).permit(
      :activity_type,
      :description,
      :occurred_at,
      metadata: {}
    )
  end

  def serialize_activity(activity)
    {
      id: activity.id,
      activity_type: activity.activity_type,
      activity_label: activity.activity_label,
      description: activity.description,
      metadata: activity.metadata,
      occurred_at: activity.occurred_at,
      user: {
        id: activity.user.id,
        name: "#{activity.user.first_name} #{activity.user.last_name}".strip
      },
      created_at: activity.created_at
    }
  end
end