class PlantsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_lote, only: [:index, :create]
  before_action :set_plant, only: [:show, :update, :destroy]

  def index
    # GET /lotes/:lote_id/plants
    authorize @lote, :show?          # o una PlantPolicy index?
    render json: @lote.plants.order(:id)
  end

  def create
    authorize @lote, :update?        # o PlantPolicy :create?
    plant = @lote.plants.new(plant_params.merge(created_by: current_user))
    if plant.save
      render json: plant, status: :created
    else
      render json: { errors: plant.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def show
    authorize @plant, :show?
    render json: @plant
  end

  def update
    authorize @plant, :update?
    if @plant.update(plant_params)
      render json: @plant
    else
      render json: { errors: @plant.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @plant = Plant.find(params[:id])
    authorize @plant.lote, :update?   # misma policy que para update
    @plant.destroy
    head :no_content
  end

  private

  def set_lote
    @lote = Lote.find(params[:lote_id])
  end

  def set_plant
    @plant = Plant.find(params[:id])
  end

  def plant_params
    params.require(:plant).permit(:code, :strain, :stage, :health, :photo_url, :notes)
  end
end
