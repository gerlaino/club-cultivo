class ReglaAmbiental < ApplicationRecord
  self.table_name = 'reglas_ambientales'

  belongs_to :club
  acts_as_tenant(:club)
  belongs_to :sala, optional: true
  has_many   :alertas, foreign_key: :regla_id, dependent: :destroy

  CONDICIONES = %w[gt lt gte lte between out_of_range].freeze
  ACCIONES    = %w[notificar crear_tarea webhook todas].freeze
  PRIORIDADES = %w[baja media alta critica].freeze

  validates :nombre,           presence: true
  validates :tipo_lectura,     inclusion: { in: AmbienteTipos::TIPOS }
  validates :condicion,        inclusion: { in: CONDICIONES }
  validates :accion,           inclusion: { in: ACCIONES }
  validates :prioridad,        inclusion: { in: PRIORIDADES }
  validates :umbral_a,         presence: true, numericality: true
  validates :umbral_b,         numericality: true, allow_nil: true
  validates :duracion_minutos, presence: true,
                               numericality: { only_integer: true, greater_than: 0 }
  validate  :umbral_b_requerido_para_rango

  scope :activas,            -> { where(activa: true) }
  scope :activas_para_sala,  ->(sala_id) {
    activas.where('sala_id = ? OR sala_id IS NULL', sala_id)
  }

  def viola?(valor)
    v = valor.to_f
    case condicion
    when 'gt'           then v >  umbral_a
    when 'lt'           then v <  umbral_a
    when 'gte'          then v >= umbral_a
    when 'lte'          then v <= umbral_a
    when 'between'      then v >= umbral_a && v <= umbral_b
    when 'out_of_range' then v <  umbral_a || v >  umbral_b
    else false
    end
  end

  def alerta_activa_para?(sala_id)
    alertas.where(sala_id: sala_id, estado: %w[activa reconocida]).exists?
  end

  private

  def umbral_b_requerido_para_rango
    return unless %w[between out_of_range].include?(condicion)
    errors.add(:umbral_b, 'es requerido para condiciones between/out_of_range') if umbral_b.nil?
  end
end
