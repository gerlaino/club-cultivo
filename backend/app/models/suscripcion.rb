# El cobro recurrente de una organización con Mercado Pago (12-oct-2026). Es de la PLATAFORMA, no
# del dominio de la organización: no lleva tenant (la escribe el webhook, que no tiene usuario).
# Una sola viva por organización: generar otra cancela la anterior (`Pagos::Suscripciones::Crear`).
class Suscripcion < ApplicationRecord
  self.table_name = 'suscripciones'

  belongs_to :club
  belongs_to :creada_por, class_name: 'User', optional: true
  has_many :cobros, -> { order(cobrado_at: :desc) }, class_name: 'SuscripcionCobro', dependent: :destroy

  ESTADOS = %w[pendiente activa pausada cancelada].freeze
  ORIGENES = %w[organizacion autocultivo].freeze
  ESTADO_LABEL = { 'pendiente' => 'Esperando que se suscriba', 'activa' => 'Activa',
                   'pausada' => 'Pausada', 'cancelada' => 'Cancelada' }.freeze
  # Cómo dice Mercado Pago cada estado de un preapproval.
  ESTADO_MP = { 'pending' => 'pendiente', 'authorized' => 'activa', 'paused' => 'pausada', 'cancelled' => 'cancelada' }.freeze

  validates :estado, inclusion: { in: ESTADOS }
  validates :origen, inclusion: { in: ORIGENES }
  validates :monto_ars, numericality: { greater_than: 0 }
  validates :payer_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :motivo, presence: true

  scope :vivas, -> { where(estado: %w[pendiente activa pausada]) }

  def estado_label = ESTADO_LABEL[estado]
end
