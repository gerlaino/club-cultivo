class Plant < ApplicationRecord
  include RestorableInterface
  include Auditable
  belongs_to :deleted_by, class_name: "User", optional: true
  belongs_to :lote
  belongs_to :club, optional: true
  acts_as_tenant(:club)
  belongs_to :planta_madre, class_name: 'Plant', optional: true

  has_many   :esquejes, class_name: 'Plant', foreign_key: :planta_madre_id, dependent: :nullify
  has_many :activities, class_name: 'PlantActivity', dependent: :destroy
  has_many :observaciones, as: :noteable, dependent: :destroy
  has_many :pesadas_plantas, class_name: 'PesadaPlanta', dependent: :destroy

  # set_club_id corre en before_validation (no before_create): acts_as_tenant exige
  # el tenant en la validación, y el club_id de la planta se deriva del lote.
  before_validation :set_club_id
  before_create :generate_codigo_qr
  has_one_attached  :foto
  has_many_attached :fotos

  default_scope { where(deleted_at: nil) }

  STATES   = %w[enraizado vegetativo floracion secado cosechado descartada].freeze
  ORIGENES = %w[semilla esqueje].freeze

  # La planta todavía no tiene raíz funcional. Un descarte acá es, por defecto, un esqueje o una
  # plántula que NO PRENDIÓ — que es justo lo que hay que poder medir.
  ESTADOS_ENRAIZANDO = %w[enraizado].freeze

  # Motivo estructurado del descarte. Convive con el texto libre (que va a notas): el texto explica
  # el caso, este permite contarlo.
  MOTIVOS_DESCARTE = %w[no_prendio plaga enfermedad macho hermafrodita estres rotura otro].freeze

  validates :nombre,    presence: true
  validates :state,     inclusion: { in: STATES }
  validates :codigo_qr, uniqueness: true, allow_nil: true
  validates :peso_seco, numericality: { greater_than: 0 }, allow_nil: true
  validates :origen,    inclusion: { in: ORIGENES }, allow_nil: true
  validates :motivo_descarte, inclusion: { in: MOTIVOS_DESCARTE }, allow_nil: true

  scope :por_estado,     ->(estado) { where(state: estado) }
  scope :seleccion,      -> { where(es_seleccion: true) }
  scope :enraizadas,     -> { where(state: 'enraizado') }
  scope :en_vegetativo,  -> { where(state: 'vegetativo') }
  scope :en_floracion,   -> { where(state: 'floracion') }
  scope :en_secado,      -> { where(state: 'secado') }
  scope :cosechadas,     -> { where(state: 'cosechado') }

  scope :descartadas,    -> { where(state: 'descartada') }
  scope :no_prendieron,  -> { where(motivo_descarte: 'no_prendio') }
  scope :enraizando,     -> { where(state: ESTADOS_ENRAIZANDO) }

  def soft_delete!
    update_column(:deleted_at, Time.current)
  end

  private

  def set_club_id
    self.club_id ||= lote&.club_id
  end

  def generate_codigo_qr
    self.codigo_qr = "#{lote.club_id}-#{lote.id}-#{Time.now.to_i}-#{SecureRandom.hex(4)}"
  end
end
