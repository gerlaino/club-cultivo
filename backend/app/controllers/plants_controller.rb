# backend/app/controllers/plants_controller.rb
class PlantsController < ApplicationController
  before_action :authenticate_user!

  # GET /lotes/:lote_id/plants  (o con params[:sala_id] ver más abajo)
  def index
    if params[:sala_id].present?
      # Traer todas las plantas de la sala (join via lotes)
      @plants = Plant.joins(:lote).where(lotes: { sala_id: params[:sala_id] })
    else
      @lote = Lote.find(params[:lote_id])
      authorize @lote, :show?
      @plants = @lote.plants
    end
    render json: @plants
  end

  # GET /plants/:id
  def show
    @plant = Plant.find(params[:id])
    authorize @plant.lote, :show?
    render json: @plant
  end

  # POST /lotes/:lote_id/plants
  def create
    @lote = Lote.find(params[:lote_id])
    authorize @lote, :update?

    @plant = @lote.plants.new(plant_params.merge(created_by: current_user))
    if @plant.save
      render json: @plant, status: :created
    else
      render json: { errors: @plant.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /plants/:id
  def update
    @plant = Plant.find(params[:id])
    authorize @plant.lote, :update?

    if @plant.update(plant_params)
      render json: @plant
    else
      render json: { errors: @plant.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # backend/app/controllers/plants_controller.rb
  def destroy
    @plant = Plant.find(params[:id])
    authorize @plant.lote, :update?   # misma policy que para update
    @plant.destroy
    head :no_content
  end


  private

  def plant_params
    params.require(:plant).permit(:code, :strain, :stage, :health, :photo_url, :notes)
  end
end

