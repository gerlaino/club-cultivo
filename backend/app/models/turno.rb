class Turno < ApplicationRecord
  belongs_to :paciente
  belongs_to :medico, class_name: 'User'
  belongs_to :club
  acts_as_tenant(:club)

  TIPOS   = %w[primera_vez seguimiento revision urgencia].freeze
  ESTADOS = %w[programado confirmado realizado cancelado ausente].freeze

  validates :fecha_hora, presence: true
  validates :tipo,   inclusion: { in: TIPOS }
  validates :estado, inclusion: { in: ESTADOS }
  validate  :no_modificar_si_realizado, on: :update

  before_destroy :impedir_borrar_si_realizado

  scope :proximos,   -> { where('fecha_hora >= ?', Time.current).order(:fecha_hora) }
  scope :pasados,    -> { where('fecha_hora < ?',  Time.current).order(fecha_hora: :desc) }
  scope :del_medico, ->(user_id) { where(medico_id: user_id) }

  def realizado?
    estado == 'realizado'
  end

  private

  # Un turno ya realizado no se puede reprogramar (cambiar fecha) ni cancelar.
  # Sí se permite seguir cargando notas posteriores (notas_post).
  def no_modificar_si_realizado
    return unless estado_was == 'realizado'

    if fecha_hora_changed?
      errors.add(:base, 'No se puede reprogramar un turno ya realizado')
    end
    if estado_changed? && estado == 'cancelado'
      errors.add(:base, 'No se puede cancelar un turno ya realizado')
    end
  end

  def impedir_borrar_si_realizado
    return unless estado == 'realizado'
    errors.add(:base, 'No se puede eliminar un turno ya realizado')
    throw :abort
  end
end
