class Webhook < ApplicationRecord
  belongs_to :club
  belongs_to :created_by, class_name: 'User'
  has_many   :webhook_deliveries, dependent: :destroy

  EVENTS = %w[
    dispensacion.creada
    paciente.creado
    lote.avanzado
    cosecha.completada
  ].freeze

  validates :nombre, presence: true
  validates :url,    presence: true, format: { with: /\Ahttps?:\/\/.+/, message: 'debe ser una URL válida' }
  validates :secret, presence: true
  validate  :events_validos

  scope :activos, -> { where(active: true) }

  def events_array
    JSON.parse(events)
  rescue
    []
  end

  def events_array=(arr)
    self.events = arr.to_json
  end

  def escucha?(event)
    events_array.include?(event)
  end

  private

  def events_validos
    arr = events_array
    invalid = arr - EVENTS
    errors.add(:events, "contiene eventos inválidos: #{invalid.join(', ')}") if invalid.any?
    errors.add(:events, 'debe tener al menos un evento') if arr.empty?
  end
end
