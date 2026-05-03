class Dispositivo < ApplicationRecord
  belongs_to :club
  belongs_to :sala
  has_many   :lecturas_ambientales, dependent: :nullify

  encrypts :metadata, deterministic: false

  TIPOS   = %w[pulse bluelab tuya_plug shelly_plug melcloud_ac daikin generic].freeze
  ESTADOS = %w[activo mantenimiento baja].freeze

  validates :nombre_amigable, presence: true
  validates :tipo,   inclusion: { in: TIPOS,   message: "'%{value}' no es un tipo de dispositivo válido" }
  validates :estado, inclusion: { in: ESTADOS, message: "'%{value}' no es un estado válido" }

  scope :activos, -> { where(estado: 'activo') }

  def activo?     = estado == 'activo'
  def en_baja?    = estado == 'baja'

  def webhook_token_matches?(plain_token)
    return false unless webhook_token_digest.present? && plain_token.present?
    BCrypt::Password.new(webhook_token_digest) == plain_token
  rescue BCrypt::Errors::InvalidHash
    false
  end

  def regenerar_token!
    plain = SecureRandom.hex(32)
    update!(
      webhook_token_digest:  BCrypt::Password.create(plain),
      last_token_rotated_at: Time.current
    )
    plain
  end

  # true mientras el sensor no haya confirmado el nuevo token con un ping exitoso
  def token_pendiente_confirmacion?
    last_token_rotated_at.present? &&
      (ultima_lectura_at.nil? || ultima_lectura_at < last_token_rotated_at)
  end
end
