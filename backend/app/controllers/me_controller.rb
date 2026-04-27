class MeController < ApplicationController
  before_action :authenticate_user!

  def show
    render json: current_user.as_json(
      only: %i[id email role club_id first_name last_name dni birthdate phone avatar_url created_at updated_at]
    )
  end

  def movimientos
    movs = current_user.club.inventario_movimientos
                       .where(created_by: current_user)
                       .includes(:sede_inventario, :lote)
                       .order(created_at: :desc)
                       .limit(30)
    render json: movs.map { |m|
      {
        id:              m.id,
        tipo:            m.tipo,
        cantidad:        m.cantidad,
        estado:          m.estado,
        motivo:          m.motivo,
        nota_rechazo:    m.nota_rechazo,
        created_at:      m.created_at,
        lote_codigo:     m.lote&.codigo,
        genetica_nombre: m.sede_inventario&.genetica&.nombre || m.sede_inventario&.producto,
      }
    }
  end
end

