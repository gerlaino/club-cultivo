class StatsController < ApplicationController
  before_action :authenticate_user!

  def show
    club = current_user.club
    data = Rails.cache.fetch("stats/club/#{club.id}", expires_in: 5.minutes) do
      lote_ids      = club.lotes.pluck(:id)
      plantas_scope = Plant.where(lote_id: lote_ids)
      plantas_act   = plantas_scope.where.not(state: %w[cosechado descartada])

      vencidos_count   = club.pacientes.where.not(reprocann_vencimiento: nil)
                             .where('reprocann_vencimiento < ?', Date.today).count
      por_vencer_count = club.pacientes.reprocann_por_vencer.count

      {
        pacientes:            club.pacientes.count,
        plantas:              plantas_act.count,
        salas:                club.salas.count,
        lotes:                club.lotes.count,
        vencimientos:         vencidos_count,
        reprocann_vencidos:   vencidos_count,
        reprocann_por_vencer: por_vencer_count,
        germinacion:          plantas_act.where(state: 'germinacion').count,
        vegetativo:           plantas_act.where(state: 'vegetativo').count,
        floracion:            plantas_act.where(state: 'floracion').count,
        secado:               plantas_act.where(state: 'secado').count,
        plantas_por_genetica: plantas_por_genetica(club, lote_ids),
        salas_ocupacion:      salas_ocupacion(club),
        plantas_por_sede:     plantas_por_sede(club, lote_ids),
        plantas_por_lote:     plantas_act.group(:lote_id).count,
      }
    end
    render json: data
  end

  private

  def plantas_por_genetica(club, lote_ids)
    scope = Genetica.where(global: true).or(Genetica.where(club_id: club.id))
    scope.where(activa: true).map do |g|
      plantas_activas = Plant.joins(:lote)
                             .where(lotes: { club_id: club.id, genetica_id: g.id })
                             .where.not(plants: { state: %w[cosechado descartada] })
                             .count
      {
        id:            g.id,
        nombre:        g.nombre,
        tipo:          g.tipo,
        plantas_count: plantas_activas,
      }
    end
  end

  # Plantas vivas por sala de cultivo (sin capacidad — la sala no tiene tope).
  def salas_ocupacion(club)
    club.salas.cultivo.includes(:lotes).map do |sala|
      plantas_count = Plant.joins(:lote)
                           .where(lotes: { sala_id: sala.id })
                           .where.not(plants: { state: %w[cosechado descartada] })
                           .count
      {
        sala_id:      sala.id,
        nombre:       sala.nombre,
        sede_id:      sala.sede_id,
        plants_count: plantas_count,
      }
    end
  end

  def plantas_por_sede(club, lote_ids)
    result = Plant.joins(lote: { sala: :sede })
                  .where(lotes: { club_id: club.id })
                  .where.not(plants: { state: %w[cosechado descartada] })
                  .group('sedes.id')
                  .count
    result.map { |sede_id, count| { sede_id: sede_id, plantas_count: count } }
  end
end
