class PlanTarea < ApplicationRecord
  include Restorable
  belongs_to :plan_trabajo
  belongs_to :responsable, class_name: 'User', optional: true
  belongs_to :sala, optional: true
  belongs_to :tarea_generada, class_name: 'Tarea', optional: true

  # Los MISMOS que Tarea: una PlanTarea se materializa como Tarea al aplicar el plan, así que
  # dos listas distintas garantizan que algo se rompa. Acá faltaban nutricion, defoliacion,
  # scrog_lst, ajuste_luz y revision_plagas —que el formulario sí ofrece—, y guardar el plan
  # devolvía un 422 sin que se entendiera por qué.
  TIPOS       = Tarea::TIPOS
  PRIORIDADES = Tarea::PRIORIDADES
  DIAS_VALIDOS = %w[lun mar mie jue vie sab dom].freeze

  validates :tipo,      inclusion: { in: TIPOS }
  validates :prioridad, inclusion: { in: PRIORIDADES }
  validate  :dias_semana_validos
  validates :dia_relativo, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  before_create :assign_recurrencia_id, if: :es_recurrente?

  scope :recurrentes, -> { where(es_recurrente: true) }
  scope :unicas,      -> { where(es_recurrente: false) }
  scope :confirmadas, -> { where(confirmada: true) }
  scope :ambiguas,    -> { where(confirmada: false) }

  def dias_array
    return [] if dias_semana.blank?
    dias_semana.split(',').map(&:strip)
  end

  def titulo_display
    titulo.presence || tipo.humanize
  end

  private

  def dias_semana_validos
    return unless dias_semana.present?
    invalidos = dias_array - DIAS_VALIDOS
    errors.add(:dias_semana, "contiene días inválidos: #{invalidos.join(', ')}") if invalidos.any?
  end

  def assign_recurrencia_id
    self.recurrencia_id = SecureRandom.uuid if recurrencia_id.blank?
  end
end
