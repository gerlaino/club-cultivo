class StatsController < ApplicationController
  before_action :authenticate_user!

  def show
    club_id = current_user.club_id
    render json: {
      salas_count:  Sala.where(club_id: club_id).count,
      lotes_count:  Lote.joins(:sala).where(salas: { club_id: club_id }).count,
      socios_count: Socio.where(club_id: club_id).count,
      users_count:  User.where(club_id: club_id).count
    }
  end
end

