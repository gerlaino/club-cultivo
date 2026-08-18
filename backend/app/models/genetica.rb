class Genetica < ApplicationRecord
  include Restorable
  # has_global_records: las genéticas globales (club_id nil) son un catálogo compartido
  # visible para todos los clubes, además de las genéticas propias de cada club.
  # optional: true → club_id nil es válido (genéticas globales no pertenecen a un club).
  acts_as_tenant(:club, has_global_records: true, optional: true)
  has_many :lotes, dependent: :nullify
  has_many :resenas, class_name: 'ResenaProducto', dependent: :destroy
  has_many_attached :fotos

  # ── Declaración ante el INASE ─────────────────────────────────────────────
  #
  # Los clubes cultivan genéticas que no están inscriptas y las etiquetan contra una variedad
  # que sí lo está. Esto guarda ese par: "Northern Lights se declara como ANANDA001".
  #
  # Apunta al catálogo GLOBAL de variedades registradas (club_id NULL), que ya existe: no se
  # duplica por club. Es opcional — declarar es una tarea que el club hace cuando puede, y
  # bloquear el alta por eso trabaría el trabajo diario. Las que quedan sin declarar salen
  # listadas aparte en el informe INASE.
  belongs_to :declarada_como, class_name: 'Genetica', optional: true
  has_many   :declaradas_asi, class_name: 'Genetica', foreign_key: :declarada_como_id,
                              dependent: :nullify, inverse_of: :declarada_como

  validate :declaracion_valida, if: -> { declarada_como_id.present? }

  scope :registradas,      -> { where(registrada_inase: true) }
  scope :sin_declarar,     -> { where(registrada_inase: [false, nil], declarada_como_id: nil) }
  # El catálogo que se le ofrece al club para declarar: las variedades inscriptas de verdad.
  #
  # `unscoped` está para escapar del scope de tenant —el catálogo es global, sin `club_id`— pero
  # se llevaba puesto de paso el `default_scope` de `acts_as_paranoid`, así que una variedad
  # BORRADA del catálogo seguía apareciendo en el selector. El filtro de borrados se repone a
  # mano; el de tenant sigue afuera, que es lo que se quería saltear.
  scope :declarables,      -> { unscoped.where(club_id: nil, registrada_inase: true, deleted_at: nil).order(:nombre) }

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

  # Con qué nombre sale esta genética en un informe REGULATORIO: la variedad contra la que se
  # declara si hay una, y si no la propia. En las pantallas internas NO se usa — el cultivador
  # trabaja con "Northern Lights", y ver "ANANDA001" en su lista de lotes no le dice nada.
  def nombre_declarado
    declarada_como&.nombre.presence || nombre
  end

  # Cómo se nombra PUERTAS ADENTRO: el nombre con el que trabaja la organización, y entre
  # paréntesis la variedad contra la que declara. Es lo que va en etiquetas e informes internos.
  #
  # El separador NO es "x": en cannabis `A x B` significa un CRUCE, así que "CELOSA 10 x Blue
  # Sherbet" se leería como que la planta es hija de esas dos —lo contrario de lo que dice—.
  # Y el propio va primero porque es el que la gente usa todos los días; el acreditable es el
  # dato de respaldo.
  #
  # Ojo: en los informes REGULATORIOS va `nombre_declarado` (sólo el del INASE), no éste.
  def nombre_visible
    return nombre unless declarada_como

    "#{nombre} (#{declarada_como.nombre})"
  end

  # El número que le corresponde ante el organismo: el propio si está inscripta, el de la
  # variedad contra la que se declara si no.
  def numero_inase_declarado
    return numero_registro_inase if registrada_inase?

    declarada_como&.numero_registro_inase
  end

  # ¿Este club puede acreditar esta genética? O está inscripta, o declara contra una que lo está.
  def acreditada_inase?
    registrada_inase? || declarada_como.present?
  end

  private

  def declaracion_valida
    if registrada_inase?
      errors.add(:declarada_como, 'no corresponde: esta variedad ya está inscripta en el INASE')
      return
    end

    if declarada_como_id == id
      errors.add(:declarada_como, 'no puede ser la genética misma')
      return
    end

    # `unscoped` por lo mismo que en `declarables`: el destino es global y hay tenant fijado.
    destino = Genetica.unscoped.find_by(id: declarada_como_id)
    if destino.nil?
      errors.add(:declarada_como, 'no existe')
    elsif !destino.registrada_inase?
      errors.add(:declarada_como, 'tiene que ser una variedad inscripta en el INASE')
    elsif destino.deleted_at.present? && declarada_como_id_changed?
      # Sólo al CAMBIAR la declaración. Si se valida siempre, una variedad borrada después vuelve
      # inguardable a toda genética que la declaraba: no se podría ni corregirle una falta de
      # ortografía al nombre, que es justamente lo que haría falta para poder redeclararla.
      errors.add(:declarada_como, 'fue eliminada del catálogo del INASE')
    end
  end

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