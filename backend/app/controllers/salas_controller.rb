class SalasController < ApplicationController
  before_action :authenticate_user!
  before_action :set_sala, only: [:show, :update, :destroy]

  def index
    @salas = policy_scope(Sala)
    render json: @salas
  end

  def show
    authorize @sala
    render json: @sala
  end

  def create
    @sala = Sala.new(sala_params.merge(club_id: current_user.club_id))
    authorize @sala
    if @sala.save
      render json: @sala, status: :created
    else
      render json: { errors: @sala.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    authorize @sala
    if @sala.update(sala_params)
      render json: @sala
    else
      render json: { errors: @sala.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @sala
    @sala.destroy
    head :no_content
  end

  private
  def set_sala; @sala = Sala.find(params[:id]); end
  def sala_params; params.require(:sala).permit(:name, :state, :pots_count, :notes); end
end
