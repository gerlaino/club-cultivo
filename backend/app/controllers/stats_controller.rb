class StatsController < ApplicationController
  before_action :authenticate_user!

  def show
    club_id = current_user.club_id

    salas_scope = Sala.where(club_id: club_id)
    lotes_scope = Lote.where(club_id: club_id)

    salas_por_estado = salas_scope.group(:state).count # {"activa"=>X, "inactiva"=>Y, ...}
    lotes_por_etapa  = lotes_scope.group(:stage).count # {"vegetativo"=>X, "floracion"=>Y, "cosechado"=>Z}

    total_macetas    = salas_scope.sum(:pots_count)
    plantas_activas  = lotes_scope.where.not(stage: "cosechado").sum(:plants_count)

    render json: {
      salas: {
        total: salas_scope.count,
        por_estado: salas_por_estado
      },
      lotes: {
        total: lotes_scope.count,
        por_etapa: lotes_por_etapa
      },
      ocupacion: {
        total_macetas: total_macetas,
        plantas_activas: plantas_activas
      }
    }
  end
end
