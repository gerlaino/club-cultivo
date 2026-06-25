class PlanTrabajo < ApplicationRecord
  belongs_to :club
  acts_as_tenant(:club)
  belongs_to :creado_por, class_name: 'User'
  belongs_to :sede, optional: true
  has_many   :plan_tareas, dependent: :destroy
  has_many   :tareas_generadas, class_name: 'Tarea', foreign_key: :origen_plan_id, dependent: :nullify

  enum :periodo_tipo, { semanal: 0, mensual: 1, trimestral: 2 }
  enum :estado,       { borrador: 0, publicado: 1, archivado: 2 }

  has_many :aplicaciones, class_name: 'AplicacionPlan', dependent: :destroy

  validates :titulo,       presence: true, length: { maximum: 200 }
  validates :fecha_inicio, presence: true, unless: :es_plantilla?
  validates :fecha_fin,    presence: true, unless: :es_plantilla?
  validate  :fecha_fin_posterior, unless: :es_plantilla?

  scope :del_club,     ->(club_id) { where(club_id: club_id) }
  scope :publicados,   -> { where(estado: :publicado) }
  scope :vigentes,     -> { publicados.where('fecha_fin >= ?', Date.today) }
  scope :recientes,    -> { order(created_at: :desc) }
  scope :plantillas,   -> { where(es_plantilla: true) }
  scope :no_plantillas,-> { where(es_plantilla: false) }

  def duracion_dias
    return nil if es_plantilla? || fecha_inicio.nil? || fecha_fin.nil?
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
