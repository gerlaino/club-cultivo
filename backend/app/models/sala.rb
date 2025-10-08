class Sala < ApplicationRecord
  belongs_to :club

  validates :name, presence: true, uniqueness: { scope: :club_id }
end
