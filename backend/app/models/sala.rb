class Sala < ApplicationRecord
  belongs_to :club
  has_many :lotes, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :club_id }

  belongs_to :created_by, class_name: "User", optional: true

  enum state: { activa: "activa", mantenimiento: "mantenimiento", cerrada: "cerrada" }, _prefix: true

  # Campo derivado para el frontend
  def created_by_name
    created_by&.email
  end
end
