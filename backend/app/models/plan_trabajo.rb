class PlanTrabajo < ApplicationRecord
  belongs_to :club
  belongs_to :creado_por, class_name: 'User'
  belongs_to :sede, optional: true
  has_many   :plan_tareas, dependent: :destroy
  has_many   :tareas_generadas, class_name: 'Tarea', foreign_key: :origen_plan_id, dependent: :nullify

  enum :periodo_tipo, { semanal: 0, mensual: 1, trimestral: 2 }
  enum :estado,       { borrador: 0, publicado: 1, archivado: 2 }

  validates :titulo,       presence: true, length: { maximum: 200 }
  validates :fecha_inicio, presence: true
  validates :fecha_fin,    presence: true
  validate  :fecha_fin_posterior

  scope :del_club,    ->(club_id) { where(club_id: club_id) }
  scope :publicados,  -> { where(estado: :publicado) }
  scope :vigentes,    -> { publicados.where('fecha_fin >= ?', Date.today) }
  scope :recientes,   -> { order(created_at: :desc) }

  def duracion_dias
    (fecha_fin - fecha_inicio).to_i + 1
  end

  def total_plan_tareas
    plan_tareas.count
  end

  def porcentaje_completado
    total = tareas_generadas.count
    return 0 if total.zero?
    completadas = tareas_generadas.where(estado: 'completada').count
    (completadas * 100.0 / total).round
  end

  private

  def fecha_fin_posterior
    return unless fecha_inicio && fecha_fin
    errors.add(:fecha_fin, 'debe ser posterior a la fecha de inicio') if fecha_fin <= fecha_inicio
  end
end
