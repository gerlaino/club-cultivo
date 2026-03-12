class StatsController < ApplicationController
  before_action :authenticate_user!

  def show
    club = current_user.club

    render json: {
      socios: club.socios.count,
      plantas: Plant.where(lote_id: club.lotes.pluck(:id)).count,
      plantas_por_genetica: plantas_por_genetica(club),
      salas: club.salas.count,
      lotes: club.lotes.count,

      vegetativo: Plant.where(lote_id: club.lotes.pluck(:id), state: 'vegetativo').count,
      floracion: Plant.where(lote_id: club.lotes.pluck(:id), state: 'floracion').count,
      secado: Plant.where(lote_id: club.lotes.pluck(:id), state: 'secado').count,

      pacientes: club.socios.count,
      vencimientos: club.socios.reprocann_por_vencer.count,
      indicaciones: 0,

      actividad: []
    }
  end

  private

  def plantas_por_genetica(club)
    Genetica.where(club_id: club.id, activa: true).map do |genetica|
      {
        id: genetica.id,
        nombre: genetica.nombre,
        tipo: genetica.tipo,
        plantas_count: Plant.joins(:lote).where(lotes: { club_id: club.id }, genetica_id: genetica.id).count
      }
    end
  end
end