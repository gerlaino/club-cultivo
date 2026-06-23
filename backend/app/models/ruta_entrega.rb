class RutaEntrega < ApplicationRecord
  self.table_name = 'rutas_entrega'

  belongs_to :club
  belongs_to :delivery, class_name: 'User'
  has_many   :dispensaciones, class_name: 'Dispensacion', dependent: :nullify

  validates :fecha, presence: true

  # La ruta de un repartidor para una fecha (la crea si no existe).
  def self.para(club:, delivery_id:, fecha:)
    where(club_id: club.id, delivery_id: delivery_id, fecha: fecha)
      .first_or_create!(club: club, delivery_id: delivery_id, fecha: fecha)
  end
end
