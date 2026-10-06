class Turno < ApplicationRecord
  include Restorable
  include Transmite
  transmite_como 'turnos'
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
  validate  :paciente_y_medico_de_la_organizacion

  # «Lo vi» (6-oct-2026): el turno que se da el propio médico nace visto; el que le da
  # administración, no, hasta que lo confirma. Si se lo mueven, vuelve a quedar sin ver.
  before_create :nace_visto_si_lo_dio_el_medico
  before_update :sin_ver_si_lo_movio_otro
  # Dar un turno vincula al paciente con ese médico (Javi: «se vincula directo»): si no, el
  # médico tendría un turno con alguien que no puede abrir.
  after_create  :vincular_paciente_con_medico

  before_destroy :impedir_borrar_si_realizado

  scope :proximos,   -> { where('fecha_hora >= ?', Time.current).order(:fecha_hora) }
  scope :pasados,    -> { where('fecha_hora < ?',  Time.current).order(fecha_hora: :desc) }
  scope :del_medico, ->(user_id) { where(medico_id: user_id) }

  def realizado?
    estado == 'realizado'
  end

  def visto? = visto_at.present?

  def marcar_visto!
    update_columns(visto_at: Time.current, updated_at: Time.current) unless visto?
    transmitir_cambio
  end

  private

  def nace_visto_si_lo_dio_el_medico
    self.visto_at ||= Time.current if Current.user && Current.user.id == medico_id
  end

  def sin_ver_si_lo_movio_otro
    return unless will_save_change_to_fecha_hora? || will_save_change_to_medico_id?
    self.visto_at = (Current.user && Current.user.id == medico_id) ? Time.current : nil
  end

  def vincular_paciente_con_medico
    MedicoPaciente.vincular!(medico: medico, paciente: paciente, por: Current.user) if medico&.medico?
  end

  # El turno, el paciente y el médico tienen que ser de la misma organización: los ids vienen del
  # navegador, y sin esto se podía dar un turno con un paciente de otra.
  def paciente_y_medico_de_la_organizacion
    errors.add(:paciente, 'no es de esta organización') if paciente && club_id && paciente.club_id != club_id
    errors.add(:medico, 'no es de esta organización')   if medico && club_id && medico.club_id != club_id
  end

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
