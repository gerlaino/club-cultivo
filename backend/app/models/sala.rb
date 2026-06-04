# backend/app/models/sala.rb
class Sala < ApplicationRecord
  belongs_to :club
  belongs_to :sede, optional: true
  belongs_to :created_by,  class_name: "User", optional: true
  belongs_to :responsable, class_name: "User", optional: true

  has_many :lotes, dependent: :destroy
  has_many :sala_cultivadores, class_name: 'SalaCultivador', foreign_key: 'sala_id', dependent: :destroy
  has_many :cultivadores, through: :sala_cultivadores, source: :user
  has_many :notas, as: :noteable, dependent: :destroy

  ESTADOS = %w[activa mantenimiento cerrada].freeze
  KINDS   = %w[vegetativo floracion manicura cosecha mixta madre clon secado].freeze
  TIPOS   = %w[cultivo vegetativo floracion cosecha secado curado madre clones].freeze

  before_validation :set_default_state, on: :create

  validates :nombre, presence: true, uniqueness: { scope: :club_id, conditions: -> { where(deleted_at: nil) } }
  validates :state,  inclusion: { in: ESTADOS }, allow_blank: false
  validates :tipo,   inclusion: { in: TIPOS }, allow_blank: true
  validate  :manicura_requiere_sede_produccion

  private

  def set_default_state
    self.state ||= 'activa'
  end

  def manicura_requiere_sede_produccion
    return unless kind == 'manicura'
    return if sede.nil?
    unless %w[produccion mixta].include?(sede.tipo)
      errors.add(:sede, 'La sala de manicura solo puede estar en sedes de producción o mixtas')
    end
  end

  public
  validates :pots_count,  numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :plants_max,  numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  enum :state, { activa: "activa", mantenimiento: "mantenimiento", cerrada: "cerrada" }, prefix: true

  default_scope { where(deleted_at: nil) }

  scope :activas,           -> { where(state: 'activa') }
  scope :en_mantenimiento,  -> { where(state: 'mantenimiento') }
  scope :de_tipo,           ->(t) { where('tipo = ? OR kind = ?', t, t) }

  def soft_delete!
    update_column(:deleted_at, Time.current)
  end

  NOMBRES_TIPO = {
    'germinacion' => 'Germinación', 'vegetativo' => 'Vegetativo',
    'floracion'   => 'Floración',   'cosecha'    => 'Cosecha',
    'secado'      => 'Secado',
    'curado'      => 'Curado',      'manicura'   => 'Manicura',
  }.freeze

  def self.find_or_create_proceso!(sede:, tipo:, created_by: nil)
    sala = where(sede: sede).where('tipo = ? OR kind = ?', tipo, tipo).where.not(state: 'cerrada').first
    return sala if sala

    created_by ||= sede.club.users.find_by(role: 'admin') || sede.club.users.first

    nombre_base = "#{NOMBRES_TIPO[tipo.to_s] || tipo.to_s.titleize} · #{sede.nombre}"
    nombre = nombre_base
    n = 2
    while sede.club.salas.exists?(nombre: nombre)
      nombre = "#{nombre_base} (#{n})"
      n += 1
    end

    create!(
      nombre:     nombre,
      tipo:       tipo,
      kind:       tipo,
      state:      'activa',
      club:       sede.club,
      sede:       sede,
      created_by: created_by,
      plants_max: 50,
      pots_count: 50,
    )
  end

  def plantas_totales
    lotes.sum(:plants_count)
  end

  def porcentaje_ocupacion
    return 0 unless tiene_limite_capacidad?
    (plantas_totales.to_f / capacidad_maxima * 100).round(1)
  end

  def tiene_limite_capacidad?
    plants_max.to_i > 0 || pots_count.to_i > 0
  end

  def capacidad_maxima
    plants_max.to_i > 0 ? plants_max.to_i : pots_count.to_i
  end

  def capacidad_disponible
    return Float::INFINITY unless tiene_limite_capacidad?
    capacidad_maxima - plantas_totales
  end

  def created_by_name
    [created_by&.first_name, created_by&.last_name].compact.join(" ").presence || created_by&.email || "Sistema"
  end
end
