class AplicacionPlan < ApplicationRecord
  self.table_name = 'aplicacion_planes'

  belongs_to :plan_trabajo
  belongs_to :club
  acts_as_tenant(:club)
  belongs_to :aplicado_por, class_name: 'User'
  has_many   :tareas, foreign_key: :aplicacion_plan_id, dependent: :nullify

  ESTADOS = %w[activo completado cancelado].freeze

  validates :fecha_inicio, presence: true
  validates :estado, inclusion: { in: ESTADOS }

  scope :activos,    -> { where(estado: 'activo') }
  scope :recientes,  -> { order(created_at: :desc) }

  def objetivo
    return nil if objetivo_tipo.blank? || objetivo_id.blank?
    objetivo_tipo.constantize.find_by(id: objetivo_id)
  rescue NameError
    nil
  end

  def objetivo_nombre
    obj = objetivo
    return nil unless obj
    obj.respond_to?(:nombre) ? obj.nombre : obj.to_s
  end

  def porcentaje_completado
    total = tareas.count
    return 0 if total.zero?
    (tareas.where(estado: 'completada').count * 100.0 / total).round
  end
end
