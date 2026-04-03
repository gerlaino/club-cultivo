class Documento < ApplicationRecord
  belongs_to :club
  belongs_to :user
  has_one_attached :archivo

  TIPOS = %w[plan_trabajo reprocann informe_semestral otro].freeze
  ESTADOS = %w[vigente vencido pendiente].freeze

  validates :tipo,   inclusion: { in: TIPOS }
  validates :titulo, presence: true
  validates :estado, inclusion: { in: ESTADOS }

  before_save :actualizar_estado

  scope :recientes,  -> { order(created_at: :desc) }
  scope :por_tipo,   ->(tipo) { where(tipo: tipo) }
  scope :vencidos,   -> { where(estado: 'vencido') }
  scope :por_vencer, -> { where(estado: 'vigente').where('fecha_vencimiento <= ?', 30.days.from_now) }

  private

  def actualizar_estado
    return unless fecha_vencimiento.present?
    self.estado = fecha_vencimiento < Date.today ? 'vencido' : 'vigente'
  end
end