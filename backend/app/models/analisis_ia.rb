class AnalisisIa < ApplicationRecord
  self.table_name = 'analisis_ia'

  belongs_to :club
  acts_as_tenant(:club)
  belongs_to :lote, optional: true
  belongs_to :user

  TIPOS = %w[lote].freeze

  validates :tipo,     inclusion: { in: TIPOS }
  validates :contenido, presence: true

  scope :del_lote, ->(lote_id) { where(lote_id: lote_id).order(created_at: :desc) }
end
