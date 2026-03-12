# app/models/user.rb
class User < ApplicationRecord
  include Permissions

  belongs_to :club, optional: false

  has_one_attached :avatar

  # Devise modules + JWT
  devise :database_authenticatable, :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  enum role: {
    admin: 'admin',
    medico: 'medico',
    agricultor: 'agricultor',
    cultivador: 'cultivador',
    abogado: 'abogado',
    auditor: 'auditor',
    socio: 'socio'
  }

  validates :role, presence: true
  validates :email, presence: true, uniqueness: true
  validate :acceptable_avatar

  private

  def acceptable_avatar
    return unless avatar.attached?
    if avatar.byte_size > 5.megabytes
      errors.add(:avatar, "es demasiado grande (máx 5MB)")
    end
    acceptable_types = ["image/jpeg", "image/png", "image/webp"]
    errors.add(:avatar, "debe ser JPG/PNG/WebP") unless acceptable_types.include?(avatar.content_type)
  end
end

