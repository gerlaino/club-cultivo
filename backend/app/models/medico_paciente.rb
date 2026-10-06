# Qué pacientes atiende cada médico (Javi y Germán, 6-oct-2026). Un paciente puede tener más de
# un médico. El médico ve SÓLO a sus vinculados: lo aplica `PacientePolicy::Scope`, que es por
# donde pasa toda lectura de pacientes de un médico.
#
# Se vincula de tres maneras: administración desde la ficha, al darle un turno con ese médico
# (`Turno` vincula solo) y cuando el médico da de alta a un paciente (si no, lo crearía y dejaría
# de verlo).
class MedicoPaciente < ApplicationRecord
  include Transmite
  transmite_como 'pacientes'

  belongs_to :club
  acts_as_tenant(:club)
  belongs_to :medico,     class_name: 'User'
  belongs_to :paciente
  belongs_to :created_by, class_name: 'User', optional: true

  validates :paciente_id, uniqueness: { scope: :medico_id, message: 'ya está vinculado a ese médico' }
  validate  :es_medico_de_la_organizacion

  # El aviso en vivo lleva el id del PACIENTE: la ficha abierta y las listas reaccionan a «cambió
  # el paciente N», no a un vínculo que no conocen.
  def transmitir_cambio
    Transmite.emitir(club_id, recurso: 'pacientes', accion: 'actualizado', id: paciente_id)
  end

  # Vincula si no lo estaba. Idempotente: dar dos turnos no duplica nada.
  def self.vincular!(medico:, paciente:, por: nil)
    find_or_create_by!(medico: medico, paciente: paciente) do |v|
      v.club = paciente.club
      v.created_by = por
    end
  rescue ActiveRecord::RecordNotUnique
    find_by!(medico: medico, paciente: paciente)
  end

  private

  def es_medico_de_la_organizacion
    return if medico.nil? || paciente.nil?
    errors.add(:medico, 'tiene que ser un médico') unless medico.medico?
    errors.add(:medico, 'no es de esta organización') unless medico.club_id == paciente.club_id
  end
end
