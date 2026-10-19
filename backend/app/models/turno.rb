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
  # Lo que se agenda desde una pantalla —dar un turno o REPROGRAMARLO— no puede caer en una fecha u
  # hora que ya pasó (12-oct-2026: al crear lo frenaba sólo la pantalla y al reprogramar nadie).
  # Lo marca el controller (`agendando = true`); los turnos viejos que se cargan como historia
  # (realizados, la org de demo) no pasan por acá.
  attr_accessor :agendando
  validate  :no_en_el_pasado, if: -> { agendando && cambia_el_momento? }
  # UN MÉDICO, UN TURNO A LA VEZ (Germán, 19-oct-2026: «no pueden haber dos turnos en el mismo
  # horario»). Se valida al agendar o mover: el horario que ofrece la pantalla ya esconde los
  # ocupados, pero dos personas pueden elegir el mismo a la vez, o el navegador estar en otro huso.
  ESTADOS_OCUPAN = %w[programado confirmado realizado].freeze
  validate  :sin_superposicion, if: -> { agendando && ESTADOS_OCUPAN.include?(estado) && cambia_la_agenda? }

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

  # Al minuto: la pantalla manda «HH:MM:00» y un turno guardado con segundos no se «reprograma»
  # por eso (marcar como realizado el de ayer mandaba la misma hora y se rechazaba).
  def cambia_el_momento?
    return true if new_record?
    antes, despues = fecha_hora_change_to_be_saved
    antes.nil? || despues.nil? ? will_save_change_to_fecha_hora? : (despues - antes).abs >= 60
  end

  def cambia_la_agenda?
    new_record? || cambia_el_momento? || will_save_change_to_duracion_minutos? ||
      will_save_change_to_medico_id? || (will_save_change_to_estado? && !ESTADOS_OCUPAN.include?(estado_was))
  end

  # El candado por médico (hasta el fin de la transacción del save) hace que dos altas simultáneas
  # en el mismo horario no pasen las dos la validación.
  def sin_superposicion
    return unless medico_id && fecha_hora

    self.class.connection.execute("SELECT pg_advisory_xact_lock(#{self.class.connection.quote(7_301_000_000 + medico_id.to_i)})")
    fin = fecha_hora + (duracion_minutos.presence || 30).to_i.minutes
    choca = Turno.where(medico_id: medico_id, estado: ESTADOS_OCUPAN)
                 .where.not(id: id)
                 .where('fecha_hora < ?', fin)
                 .where("fecha_hora + (duracion_minutos * INTERVAL '1 minute') > ?", fecha_hora)
                 .order(:fecha_hora).first
    return unless choca

    errors.add(:base, "El médico ya tiene un turno a las #{choca.fecha_hora.in_time_zone.strftime('%H:%M')} " \
                      "del #{choca.fecha_hora.in_time_zone.strftime('%d/%m')}: elegí otro horario")
  end

  def no_en_el_pasado
    errors.add(:base, 'No se puede agendar un turno en una fecha u hora que ya pasó') if fecha_hora && fecha_hora <= Time.current
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
