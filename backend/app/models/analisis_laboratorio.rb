class AnalisisLaboratorio < ApplicationRecord
  self.table_name = 'analisis_laboratorio'

  belongs_to :lote
  belongs_to :genetica, optional: true
  belongs_to :user

  validates :club_id, presence: true
  validates :lote_id, presence: true

  scope :del_club, ->(club_id) { where(club_id: club_id) }
  scope :del_lote, ->(lote_id) { where(lote_id: lote_id) }
end
