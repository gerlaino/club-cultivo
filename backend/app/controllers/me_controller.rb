class MeController < ApplicationController
  before_action :authenticate_user!

  def show
    u = current_user
    data = u.as_json(
      only: %i[id email role club_id first_name last_name dni birthdate phone avatar_url created_at updated_at]
    )
    if u.dispensador?
      data['dispensario_sede_id'] =
        u.sedes_asignadas.activas.first&.id ||
        u.club&.sedes&.activas&.where(tipo: %w[social mixta])&.order(:id)&.first&.id
    end
    render json: data
  end

  def movimientos
    render json: []
  end
end

