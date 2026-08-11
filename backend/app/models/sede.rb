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

  # Qué suite habilita cada tipo de sede. Una sede de producción son salas, lotes y plantas
  # (suite Cultivo); una social es atención de pacientes y dispensaciones (Producción y
  # dispensa). La mixta es las dos cosas y necesita las dos.
  SUITES_POR_TIPO = {
    'produccion' => %w[cultivo],
    'social'     => %w[produccion_dispensa],
    'mixta'      => %w[cultivo produccion_dispensa],
  }.freeze

  validates :nombre, presence: true
  validates :tipo,   inclusion: { in: TIPOS }
  # Sólo al CREAR. Una organización puede dar de baja una suite y quedarse con sedes de un tipo
  # que hoy no podría crear; volverlas inguardables le impediría hasta corregirles la dirección.

  # Los tipos que ESTA organización puede crear hoy. Fuente única: la usan el modelo, el
  # onboarding y el alta de sedes. Con las dos puertas mirando listas distintas, una terminaba
  # ofreciendo lo que la otra rechazaba.
  def self.tipos_disponibles(club)
    TIPOS.select { |tipo| SUITES_POR_TIPO[tipo].all? { |s| club&.suite?(s) } }
  end

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

  # Qué suites le faltan a la organización para poder tener una sede de este tipo. Vacío = puede.
  # Lo consulta el controller al dar de alta; no es una validación del modelo porque el gateo por
  # suite en este proyecto vive en los controllers (`require_feature!`), y ponerlo en el modelo
  # volvía inguardables las sedes de las organizaciones que dieron de baja una suite.
  def self.suites_faltantes(club, tipo)
    SUITES_POR_TIPO.fetch(tipo.to_s, []).reject { |s| club&.suite?(s) }
  end
end