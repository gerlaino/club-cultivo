class Plant < ApplicationRecord
  belongs_to :lote
  belongs_to :genetica, optional: true

  before_create :generate_codigo_qr

  STATES = %w[germinacion vegetativo floracion secado cosechado].freeze

  validates :nombre, presence: true
  validates :state, inclusion: { in: STATES }
  validates :codigo_qr, uniqueness: true, allow_nil: true
  validates :peso_seco, numericality: { greater_than: 0 }, allow_nil: true

  scope :por_estado, ->(estado) { where(state: estado) }
  scope :en_germinacion, -> { where(state: 'germinacion') }
  scope :en_vegetativo, -> { where(state: 'vegetativo') }
  scope :en_floracion, -> { where(state: 'floracion') }
  scope :en_secado, -> { where(state: 'secado') }
  scope :cosechadas, -> { where(state: 'cosechado') }

  private

  def generate_codigo_qr
    self.codigo_qr = "#{lote.club_id}-#{lote.id}-#{Time.now.to_i}-#{SecureRandom.hex(4)}"
  end
end
