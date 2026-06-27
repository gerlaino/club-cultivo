class User < ApplicationRecord
  include Restorable
  include Permissions
  belongs_to :club, optional: true

  # Cifrado at-rest del DNI y teléfono del operador (Ley 25.326 art. 9).
  # NO se cifra email: es el identificador de login de Devise (uniqueness + lookup
  # en cada autenticación) — cifrarlo es alto riesgo y queda fuera del alcance ENC-01.
  encrypts :dni
  encrypts :phone

  has_one_attached :avatar
  has_many :sala_cultivadores, class_name: 'SalaCultivador', foreign_key: 'user_id', dependent: :destroy
  has_many :salas_asignadas,   through: :sala_cultivadores, source: :sala
  has_many :user_sedes,        class_name: 'UserSede', foreign_key: 'user_id', dependent: :destroy
  has_many :sedes_asignadas,   through: :user_sedes, source: :sede
  has_many :push_subscriptions, dependent: :destroy
  has_many :disponibilidad_medicos, foreign_key: :medico_id, dependent: :destroy
  has_many :turnos_como_medico, class_name: 'Turno', foreign_key: :medico_id, dependent: :destroy

  devise :database_authenticatable, :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  enum :role, {
    super_admin:  'super_admin',
    admin:        'admin',
    medico:       'medico',
    cultivador:   'cultivador',
    supervisor:   'supervisor',
    abogado:      'abogado',
    auditor:      'auditor',
    dispensador:  'dispensador',
    manicura:     'manicura',
    paciente:     'paciente',
    delivery:     'delivery',
  }

  validates :role,  presence: true
  validates :email, presence: true, uniqueness: true
  validate  :club_requerido_para_no_super_admin
  validate  :acceptable_avatar

  def nombre_completo
    "#{first_name} #{last_name}".strip
  end

  # Email REAL para mandarle notificaciones: el personal si lo cargó; si no, el de login
  # (que puede ser un identificador inventado tipo rol@club.com y rebotar).
  def email_notificacion
    email_personal.presence || email
  end

  KINDS_CULTIVADOR = %w[vegetativo floracion mixta madre clon].freeze
  KINDS_MANICURA   = %w[manicura].freeze

  def salas_ids_asignadas
    if cultivador?
      sedes = sedes_ids_asignadas
      return [] if sedes.empty?
      scope = Sala.where(club_id: club_id).where(kind: KINDS_CULTIVADOR)
      scope.where(sede_id: sedes).pluck(:id)
    elsif manicura?
      Sala.where(club_id: club_id).where(kind: KINDS_MANICURA).pluck(:id)
    else
      salas_asignadas.pluck(:id)
    end
  end

  def sedes_ids_asignadas
    sedes_asignadas.pluck(:id)
  end

  def salas_ids_en_sedes_asignadas
    sedes = sedes_ids_asignadas
    scope = Sala.where(club_id: club_id)
    # Sin sedes asignadas = acceso a todas las salas del club
    sedes.empty? ? scope.pluck(:id) : scope.where(sede_id: sedes).pluck(:id)
  end

  def observando_club
    return nil unless observer_club_id.present? && observer_expires_at&.future?
    Club.find_by(id: observer_club_id)
  end

  def modo_observador?
    observer_club_id.present? && observer_expires_at&.future?
  end

  private

  def club_requerido_para_no_super_admin
    return if super_admin?
    errors.add(:club, 'es obligatorio para este rol') if club_id.blank?
  end

  def acceptable_avatar
    return unless avatar.attached?
    errors.add(:avatar, 'es demasiado grande (máx 5MB)') if avatar.byte_size > 5.megabytes
    acceptable_types = %w[image/jpeg image/png image/webp]
    errors.add(:avatar, 'debe ser JPG/PNG/WebP') unless acceptable_types.include?(avatar.content_type)
  end
end