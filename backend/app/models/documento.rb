class Documento < ApplicationRecord
  include Restorable
  belongs_to :club
  acts_as_tenant(:club)
  belongs_to :user
  belongs_to :subido_por, class_name: 'User', foreign_key: :subido_por_id, optional: true
  belongs_to :paciente, optional: true

  has_one_attached :archivo

  TIPOS_CLINICOS = %w[reprocann receta certificado_medico estudio_clinico dni identificacion].freeze
  TIPOS_LEGALES  = %w[contrato_socio estatuto acta_asamblea reglamento_interno plan_trabajo informe_semestral otro].freeze
  TIPOS          = (TIPOS_CLINICOS + TIPOS_LEGALES).freeze
  ESTADOS        = %w[vigente vencido pendiente].freeze

  validates :tipo,   inclusion: { in: TIPOS }
  validates :titulo, presence: true
  validates :estado, inclusion: { in: ESTADOS }

  before_save :actualizar_estado

  scope :recientes,  -> { order(created_at: :desc) }
  scope :por_tipo,   ->(tipo) { where(tipo: tipo) }
  scope :vencidos,   -> { where(estado: 'vencido') }
  scope :por_vencer, -> { where(estado: 'vigente').where('fecha_vencimiento <= ?', 30.days.from_now) }
  scope :clinicos,   -> { where(tipo: TIPOS_CLINICOS) }
  scope :legales,    -> { where(tipo: TIPOS_LEGALES) }

  def categoria
    TIPOS_CLINICOS.include?(tipo) ? 'clinico' : 'legal'
  end

  private

  def actualizar_estado
    return unless fecha_vencimiento.present?
    self.estado = fecha_vencimiento < Date.today ? 'vencido' : 'vigente'
  end
end
