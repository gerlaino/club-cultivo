class Plant < ApplicationRecord
  belongs_to :lote
  belongs_to :genetica, optional: true
  belongs_to :planta_madre, class_name: 'Plant', optional: true

  has_many   :esquejes, class_name: 'Plant', foreign_key: :planta_madre_id, dependent: :nullify
  has_many :activities, class_name: 'PlantActivity', dependent: :destroy

  before_create :generate_codigo_qr
  has_one_attached :foto

  STATES = %w[germinacion vegetativo floracion secado cosechado esqueje descartada].freeze
  ORIGENES = %w[semilla esqueje division].freeze

  validates :nombre, presence: true
  validates :state, inclusion: { in: STATES }
  validates :codigo_qr, uniqueness: true, allow_nil: true
  validates :peso_seco, numericality: { greater_than: 0 }, allow_nil: true
  validates :origen, inclusion: { in: ORIGENES }, allow_nil: true

  scope :por_estado, ->(estado) { where(state: estado) }
  scope :en_germinacion, -> { where(state: 'germinacion') }
  scope :en_vegetativo, -> { where(state: 'vegetativo') }
  scope :en_floracion, -> { where(state: 'floracion') }
  scope :en_secado, -> { where(state: 'secado') }
  scope :cosechadas, -> { where(state: 'cosechado') }
  scope :esqueje, -> { where(state: 'esqueje') }
  scope :descartadas, -> { where(state: 'descartada') }

  private

  def generate_codigo_qr
    self.codigo_qr = "#{lote.club_id}-#{lote.id}-#{Time.now.to_i}-#{SecureRandom.hex(4)}"
  end
end
