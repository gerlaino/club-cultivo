class LotesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_lote, only: [:show, :update, :destroy]
  before_action :set_sala, only: [:index, :create], if: -> { params[:sala_id].present? }

  def index
    if params[:sala_id].present?
      @lotes = policy_scope(Lote).where(sala_id: params[:sala_id])
    else
      @lotes = policy_scope(Lote) # opcional: podrías restringir si no quieres listado global
    end
    render json: @lotes
  end

  def create
    sala = Sala.find(params[:sala_id])
    @lote = Lote.new(lote_params.merge(sala_id: sala.id, club_id: current_user.club_id))
    authorize @lote
    if @lote.save
      render json: @lote, status: :created
    else
      render json: { errors: @lote.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def show
    authorize @lote
    render json: @lote
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

  def set_sala
    @sala = Sala.find(params[:sala_id])
    raise Pundit::NotAuthorizedError unless @sala.club_id == current_user.club_id
  end

  def set_lote
    @lote = Lote.find(params[:id])
    raise Pundit::NotAuthorizedError unless @lote.club_id == current_user.club_id
  end

  def lote_params
    params.require(:lote).permit(
      :code, :start_date, :stage, :plants_count, :strain, :notes, :sala_id,
      :grow_type, :light_type
    )
  end
end


