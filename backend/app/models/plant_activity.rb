class PlantActivity < ApplicationRecord
  belongs_to :plant
  belongs_to :user

  ACTIVITY_TYPES = %w[
    state_change
    watering
    fertilization
    pruning
    transplant
    harvest
    measurement
    note
    photo
    other
  ].freeze

  validates :activity_type, presence: true, inclusion: { in: ACTIVITY_TYPES }
  validates :occurred_at, presence: true

  scope :recent, -> { order(occurred_at: :desc) }
  scope :by_type, ->(type) { where(activity_type: type) }

  def activity_label
    {
      'state_change' => 'Cambio de estado',
      'watering' => 'Riego',
      'fertilization' => 'Fertilización',
      'pruning' => 'Poda',
      'transplant' => 'Trasplante',
      'harvest' => 'Cosecha',
      'measurement' => 'Medición',
      'note' => 'Nota',
      'photo' => 'Foto',
      'other' => 'Otro'
    }[activity_type] || activity_type
  end
end
