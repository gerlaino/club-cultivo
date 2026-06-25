class Genetica < ApplicationRecord
  # has_global_records: las genéticas globales (club_id nil) son un catálogo compartido
  # visible para todos los clubes, además de las genéticas propias de cada club.
  # optional: true → club_id nil es válido (genéticas globales no pertenecen a un club).
  acts_as_tenant(:club, has_global_records: true, optional: true)
  has_many :lotes, dependent: :nullify
  has_many_attached :fotos

  CATEGORIAS_INASE = %w[semilla_feminizada semilla_regular material_vegetativo hibrido].freeze

  validates :nombre, presence: true
  validates :slug,   presence: true, uniqueness: { scope: :club_id }
  validates :thc, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100, allow_nil: true }
  validates :cbd, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100, allow_nil: true }
  validates :tipo, inclusion: { in: %w[indica sativa hibrida], allow_nil: true }
  validates :categoria_inase, inclusion: { in: CATEGORIAS_INASE }, allow_nil: true
  validates :registrada_inase, inclusion: { in: [true], message: 'debe ser true para genéticas globales' }, if: :global?

  scope :activas,      -> { where(activa: true) }
  scope :disponibles,  -> { where(disponible: true) }
  scope :visibles_web, -> { activas.where(visible_web: true) }

  # Rendimiento real de la cepa: promedio de TODAS las plantas cosechadas con peso seco
  # (no solo "selección" — eso daba info incompleta y vacío si nadie marcaba ninguna).
  def rendimiento_promedio_seco
    PesadaPlanta
      .joins(plant: { lote: :genetica }, pesada: {})
      .where(lotes: { genetica_id: id })
      .where.not(pesadas_plantas: { peso_seco_g: nil })
      .average('pesadas_plantas.peso_seco_g')
      &.round(2)
  end

  def rendimiento_min_max_seco
    scope = PesadaPlanta
      .joins(plant: { lote: :genetica }, pesada: {})
      .where(lotes: { genetica_id: id })
      .where.not(pesadas_plantas: { peso_seco_g: nil })

    {
      min: scope.minimum('pesadas_plantas.peso_seco_g')&.round(2),
      max: scope.maximum('pesadas_plantas.peso_seco_g')&.round(2),
      n:   scope.count,
    }
  end

  default_scope { order(nombre: :asc) }

  before_validation :generar_slug, on: :create

  private

  def generar_slug
    return if slug.present?
    base = nombre.downcase
                 .gsub(/[áàäâã]/, 'a').gsub(/[éèëê]/, 'e')
                 .gsub(/[íìïî]/, 'i').gsub(/[óòöôõ]/, 'o')
                 .gsub(/[úùüû]/, 'u').gsub(/ñ/, 'n')
                 .gsub(/[^a-z0-9]+/, '-').gsub(/^-|-$/, '')
    candidate = base
    n = 2
    scope = club_id ? Genetica.where(club_id: club_id) : Genetica.where(club_id: nil)
    while scope.exists?(slug: candidate)
      candidate = "#{base}-#{n}"
      n += 1
    end
    self.slug = candidate
  end
end