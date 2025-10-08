class LotesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_lote, only: [:show, :update, :destroy]

  def index
    @lotes = policy_scope(Lote)
    render json: @lotes
  end

  def show
    authorize @lote
    render json: @lote
  end

  def create
    @lote = Lote.new(lote_params.merge(club_id: current_user.club_id))
    authorize @lote
    if @lote.save
      render json: @lote, status: :created
    else
      render json: { errors: @lote.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    authorize @lote
    if @lote.update(lote_params)
      render json: @lote
    else
      render json: { errors: @lote.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @lote
    @lote.destroy
    head :no_content
  end

  private
  def set_lote; @lote = Lote.find(params[:id]); end
  def lote_params
    params.require(:lote).permit(:code, :start_date, :stage, :plants_count, :strain, :notes, :sala_id)
  end
end
