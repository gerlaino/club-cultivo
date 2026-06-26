class Sede < ApplicationRecord
  include RestorableInterface
  belongs_to :deleted_by, class_name: "User", optional: true
  belongs_to :club
  acts_as_tenant(:club)
  belongs_to :created_by, class_name: 'User'

  has_many :salas,               dependent: :nullify
  has_many :stocks,              dependent: :restrict_with_error
  has_many :user_sedes, class_name: 'UserSede', foreign_key: 'sede_id', dependent: :destroy
  has_many :usuarios_asignados, through: :user_sedes, source: :user

  TIPOS = %w[produccion social mixta].freeze
  TIPO_LABELS = {
    'produccion' => 'Producción',
    'social'     => 'Social / Dispensario',
    'mixta'      => 'Mixta',
  }.freeze

  validates :nombre, presence: true
  validates :tipo,   inclusion: { in: TIPOS }

  default_scope { where(deleted_at: nil) }

  scope :activas,     -> { where(activa: true) }
  scope :produccion,  -> { where(tipo: ['produccion', 'mixta']) }
  scope :social,      -> { where(tipo: ['social', 'mixta']) }

  def soft_delete!
    update_column(:deleted_at, Time.current)
  end

  def tipo_label
    TIPO_LABELS[tipo] || tipo
  end

  def es_produccion?
    %w[produccion mixta].include?(tipo)
  end

  def es_social?
    %w[social mixta].include?(tipo)
  end
end