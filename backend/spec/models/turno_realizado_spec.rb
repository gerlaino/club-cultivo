require 'rails_helper'

# Un turno ya realizado no se puede reprogramar (cambiar fecha) ni eliminar/cancelar.
RSpec.describe Turno, 'protección de turnos realizados', type: :model do
  let(:club)     { create(:club) }
  let(:medico)   { create(:user, :medico, club: club) }
  let(:paciente) { create(:paciente, club: club, created_by: medico) }

  def crear_turno(estado:, fecha: 2.days.from_now)
    Turno.create!(club: club, paciente: paciente, medico: medico,
                  fecha_hora: fecha, duracion_minutos: 30, tipo: 'seguimiento', estado: estado)
  end

  context 'turno realizado' do
    let(:turno) { crear_turno(estado: 'realizado', fecha: 1.day.ago) }

    it 'no permite reprogramar (cambiar fecha_hora)' do
      turno.fecha_hora = 3.days.from_now
      expect(turno.save).to be(false)
      expect(turno.errors[:base].join).to match(/reprogramar/i)
    end

    it 'no permite cancelar' do
      turno.estado = 'cancelado'
      expect(turno.save).to be(false)
      expect(turno.errors[:base].join).to match(/cancelar/i)
    end

    it 'no permite eliminar' do
      turno # crear
      expect { turno.destroy }.not_to change(Turno, :count)
      expect(turno.destroyed?).to be(false)
    end

    it 'sí permite cargar notas posteriores' do
      turno.notas_post = 'Paciente evolucionó bien'
      expect(turno.save).to be(true)
    end
  end

  context 'turno programado (no realizado)' do
    let(:turno) { crear_turno(estado: 'programado') }

    it 'permite reprogramar' do
      turno.fecha_hora = 5.days.from_now
      expect(turno.save).to be(true)
    end

    it 'permite cancelar' do
      turno.estado = 'cancelado'
      expect(turno.save).to be(true)
    end

    it 'permite marcarlo como realizado' do
      turno.estado = 'realizado'
      expect(turno.save).to be(true)
    end
  end
end
