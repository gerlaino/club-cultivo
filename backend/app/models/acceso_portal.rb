# Un link para entrar al portal del paciente: la invitación que manda la organización o el «me
# olvidé la clave» que pide el paciente. Ver la migración `CrearAccesosPortal` para el porqué.
#
# El token crudo existe UNA sola vez, en la respuesta de `emitir!` (para armar el link); en la
# base queda su SHA-256. Buscar por token es buscar por hash.
class AccesoPortal < ApplicationRecord
  self.table_name = 'accesos_portal'

  acts_as_tenant(:club)

  MOTIVOS = %w[invitacion recuperacion].freeze
  DURACION = { 'invitacion' => 72.hours, 'recuperacion' => 6.hours }.freeze
  # Después de tantos DNI equivocados el link se cae: alguien que no es el paciente está probando.
  MAX_INTENTOS = 5

  belongs_to :club
  belongs_to :paciente
  belongs_to :creado_por, class_name: 'User', optional: true

  validates :motivo, inclusion: { in: MOTIVOS }
  validates :token_digest, :expira_at, presence: true

  Emitido = Struct.new(:acceso, :token, keyword_init: true)

  # Crea un link nuevo y anula los anteriores sin usar del mismo paciente: el último que se mandó
  # es el único que sirve, así un link viejo reenviado por error no abre nada.
  def self.emitir!(paciente, motivo: 'invitacion', creado_por: nil)
    token = SecureRandom.urlsafe_base64(32)
    acceso = nil
    transaction do
      where(paciente_id: paciente.id, usado_at: nil, anulado_at: nil).update_all(anulado_at: Time.current)
      acceso = create!(club_id: paciente.club_id, paciente: paciente, motivo: motivo, creado_por: creado_por,
                       token_digest: digest(token), expira_at: Time.current + DURACION.fetch(motivo))
    end
    Emitido.new(acceso: acceso, token: token)
  end

  def self.digest(token) = Digest::SHA256.hexdigest(token.to_s)

  # Sin tenant: el link llega de afuera, sin sesión, y de él sale la organización.
  def self.por_token(token)
    return nil if token.blank?

    ActsAsTenant.without_tenant { find_by(token_digest: digest(token)) }
  end

  # Por qué no sirve, en palabras del paciente; `nil` si sirve.
  def motivo_invalido
    return 'Este link ya se usó. Si necesitás entrar de nuevo, usá tu DNI y tu clave.' if usado_at
    return 'Este link ya no sirve: la organización te mandó uno más nuevo.' if anulado_at
    return 'Este link venció. Pedile uno nuevo a tu organización o usá «Me olvidé la clave».' if expira_at <= Time.current

    nil
  end

  def vigente? = motivo_invalido.nil?

  def registrar_intento_fallido!
    increment!(:intentos_fallidos)
    update!(anulado_at: Time.current) if intentos_fallidos >= MAX_INTENTOS
  end

  def usar! = update!(usado_at: Time.current)
end
