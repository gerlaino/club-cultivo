class User < ApplicationRecord
  include Permissions
  belongs_to :club, optional: true

  has_one_attached :avatar
  has_many :sala_cultivadores, class_name: 'SalaCultivador', foreign_key: 'user_id', dependent: :destroy
  has_many :salas_asignadas,   through: :sala_cultivadores, source: :sala
  has_many :user_sedes,        class_name: 'UserSede', foreign_key: 'user_id', dependent: :destroy
  has_many :sedes_asignadas,   through: :user_sedes, source: :sede

  devise :database_authenticatable, :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  enum role: {
    super_admin: 'super_admin',
    admin:       'admin',
    medico:      'medico',
    agricultor:  'agricultor',
    cultivador:  'cultivador',
    abogado:     'abogado',
    auditor:     'auditor',
    socio:       'socio'
  }

  validates :role,  presence: true
  validates :email, presence: true, uniqueness: true
  validate  :club_requerido_para_no_super_admin
  validate  :acceptable_avatar

  def nombre_completo
    "#{first_name} #{last_name}".strip
  end

  def salas_ids_asignadas
    salas_asignadas.pluck(:id)
  end

  def sedes_ids_asignadas
    sedes_asignadas.pluck(:id)
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