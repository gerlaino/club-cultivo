class PlantActivity < ApplicationRecord
  include Restorable
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
    registro_planta
  ].freeze

  validates :activity_type, presence: true, inclusion: { in: ACTIVITY_TYPES }
  validates :occurred_at, presence: true
  validate  :planta_en_cultivo, on: :create

  # Lo que se le hace a una planta que crece. Una nota, una foto o el cambio de estado van siempre.
  TIPOS_DE_CULTIVO = %w[watering fertilization pruning transplant measurement registro_planta].freeze

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
      'registro_planta' => 'Registro de planta',
      'other' => 'Otro'
    }[activity_type] || activity_type
  end

  private

  # Vale para todas las puertas (ficha, teléfono, dictado): una planta cosechada o descartada no
  # recibe registros de cultivo HECHOS HOY. Cargar la historia sí (un trasplante de hace 20 días en
  # un lote ya cosechado, `Lotes::RegistrarTrasplante`): pasó cuando la planta todavía crecía.
  COMO_ESTA = { 'cosechado' => 'cosechada', 'descartada' => 'descartada', 'secado' => 'en secado' }.freeze

  def planta_en_cultivo
    return unless TIPOS_DE_CULTIVO.include?(activity_type) && plant && !plant.en_cultivo?
    return if occurred_at && occurred_at < Time.zone.today.beginning_of_day

    errors.add(:base, "La planta está #{COMO_ESTA[plant.state] || plant.state}: ya no recibe registros de cultivo.")
  end
end
