class Club < ApplicationRecord
  has_many :users,                dependent: :restrict_with_error
  has_many :salas,                dependent: :destroy
  has_many :lotes,                dependent: :destroy
  has_many :socios,               dependent: :destroy
  has_many :geneticas,            dependent: :destroy
  has_many :noticias,             dependent: :destroy
  has_many :eventos,              dependent: :destroy
  has_many :sedes,                dependent: :destroy
  has_many :movimientos_contables, class_name: 'MovimientoContable', dependent: :destroy
  has_many :costo_lotes,          class_name: 'CostoLote', dependent: :destroy
  has_many :tareas,               dependent: :destroy
  has_many :documentos,           dependent: :destroy
  has_many :document_templates,   dependent: :destroy
  has_many :patient_documents,    through: :socios
  has_many :plants,               through: :lotes

  has_one_attached :logo

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_]+\z/ }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  before_validation :generar_slug, on: :create

  ROLES_DEFAULT = %w[admin medico agricultor cultivador abogado].freeze
  PASSWORD_DEFAULT = '123456Aa'.freeze

  def crear_usuarios_default!
    ROLES_DEFAULT.map do |rol|
      email = "#{rol}@#{slug}.clubcultivo.app"
      next if User.exists?(email: email)
      User.create!(
        club:       self,
        role:       rol,
        email:      email,
        password:   PASSWORD_DEFAULT,
        first_name: rol.capitalize,
        last_name:  name,
        )
    end.compact
  end

  private

  def generar_slug
    return if slug.present?
    base = name.to_s.downcase
               .gsub(/[áàäâ]/, 'a').gsub(/[éèëê]/, 'e')
               .gsub(/[íìïî]/, 'i').gsub(/[óòöô]/, 'o')
               .gsub(/[úùüû]/, 'u').gsub(/ñ/, 'n')
               .gsub(/[^a-z0-9\s]/, '').gsub(/\s+/, '_')
               .strip
    candidate = base
    counter   = 1
    while Club.where(slug: candidate).exists?
      candidate = "#{base}_#{counter}"
      counter  += 1
    end
    self.slug = candidate
  end
end