class Webhook < ApplicationRecord
  belongs_to :club
  acts_as_tenant(:club)
  belongs_to :created_by, class_name: 'User'
  has_many   :webhook_deliveries, dependent: :destroy

  EVENTS = %w[
    dispensacion.creada
    paciente.creado
    lote.avanzado
    cosecha.completada
  ].freeze

  validates :nombre, presence: true
  validates :url,    presence: true, format: { with: %r{\Ahttps?://[^\s/?#]+[^\s]*\z}, message: 'debe ser una URL válida' }
  validates :secret, presence: true
  validate  :events_validos
  validate  :destino_publico, if: -> { url.present? && will_save_change_to_url? }

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

  # El aviso al guardar; la barrera de verdad está al enviar (`OutgoingWebhookService`), porque
  # lo que resuelve un dominio puede cambiar después de guardarlo.
  def destino_publico
    host = URI.parse(url).host
    Seguridad::DestinoPublico.ip!(host)
  rescue URI::InvalidURIError
    errors.add(:url, 'debe ser una URL válida')
  rescue Seguridad::DestinoPublico::Rechazado => e
    errors.add(:url, e.message)
  end

  def events_validos
    arr = events_array
    invalid = arr - EVENTS
    errors.add(:events, "contiene eventos inválidos: #{invalid.join(', ')}") if invalid.any?
    errors.add(:events, 'debe tener al menos un evento') if arr.empty?
  end
end
