# app/models/lote.rb
class Lote < ApplicationRecord
  belongs_to :club
  belongs_to :sala

  validates :plants_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :grow_type, inclusion: { in: %w[sustrato hidroponia] }
end