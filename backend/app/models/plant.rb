class Plant < ApplicationRecord
  belongs_to :lote
  belongs_to :created_by, class_name: "User", optional: true

  validates :code, presence: true
  validates :strain, presence: true, allow_nil: true
end
