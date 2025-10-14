class SocioNota < ApplicationRecord
  acts_as_paranoid

  belongs_to :club
  belongs_to :socio

  validates :contenido, presence: true

  scope :for_club, ->(club_id) { where(club_id: club_id) }
end
