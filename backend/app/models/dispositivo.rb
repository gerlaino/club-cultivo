class Dispositivo < ApplicationRecord
  include Restorable
  belongs_to :club
  acts_as_tenant(:club)
  belongs_to :sala
  # `class_name` explícito: Rails singulariza "lecturas_ambientales" a "LecturasAmbientale" y
  # no encuentra la clase (el modelo es LecturaAmbiental, con table_name a mano). Sin esto,
  # cualquier uso de la asociación —incluido el `dependent: :nullify` al BORRAR un
  # dispositivo— tiraba NameError: dar de baja un sensor desde la UI devolvía 500.
  has_many   :lecturas_ambientales, class_name: 'LecturaAmbiental', dependent: :nullify

  encrypts :metadata, deterministic: false

  # OJO con los dos "Pulse": son de empresas distintas y miden cosas distintas.
  #   `pulse`   → Pulse Grow (pulsegrow.com): monitor ambiental fijo con WiFi que sube solo
  #               a su nube. Temperatura, humedad, luz, CO2. Es el que da lecturas continuas.
  #   `bluelab` → Bluelab Pulse: medidor PORTÁTIL de humedad y EC del sustrato, que se lee
  #               por Bluetooth con el celular. No sube nada a ningún servidor, así que sus
  #               mediciones se cargan a mano (ver LecturaManualForm).
  # La app los mostraba a los dos como "Bluelab Pulse", que es lo que hacía elegir el
  # equivocado y quedarse esperando lecturas que nunca iban a llegar.
  TIPOS   = %w[sonoff_th pulse bluelab tuya_plug shelly_plug melcloud_ac daikin generic].freeze

  # Los que mandan lecturas solos. El resto se carga a mano y no tiene sentido pedirle un
  # token de webhook a alguien que va a anotar los números del display.
  TIPOS_AUTOMATICOS = %w[sonoff_th pulse tuya_plug shelly_plug melcloud_ac daikin generic].freeze

  def automatico? = TIPOS_AUTOMATICOS.include?(tipo)
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
