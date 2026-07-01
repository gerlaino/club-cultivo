require 'rails_helper'

RSpec.describe Ambiente::AlertaCreator do
  let(:club)   { create(:club) }
  let!(:admin) { create(:user, :admin, club: club) }
  let(:sala)   { create(:sala, club: club) }
  let(:lectura) do
    create(:lectura_ambiental,
      sala: sala, club_id: club.id, tipo: 'temperatura',
      valor: 33, unidad: '°C', fuente: 'webhook', medido_at: 1.minute.ago)
  end

  def disparar(regla)
    described_class.call(sala: sala, regla: regla, lectura: lectura)
  end

  describe '.call' do
    it 'siempre crea la alerta (audit trail), sin importar la accion' do
      regla = create(:regla_ambiental, club: club, accion: 'notificar')
      expect { disparar(regla) }.to change(Alerta, :count).by(1)
    end

    it 'NO crea tarea cuando la accion es solo notificar' do
      regla = create(:regla_ambiental, club: club, accion: 'notificar')
      expect { disparar(regla) }.not_to change(Tarea, :count)
    end

    it 'crea una tarea de inspeccion cuando la accion es crear_tarea' do
      regla = create(:regla_ambiental, club: club, accion: 'crear_tarea', prioridad: 'alta')
      expect { disparar(regla) }.to change(Tarea, :count).by(1)

      tarea = Tarea.last
      expect(tarea.tipo).to eq('inspeccion')
      expect(tarea.prioridad).to eq('alta')
      expect(tarea.estado).to eq('pendiente')
      expect(tarea.sala_id).to eq(sala.id)
      expect(tarea.club_id).to eq(club.id)
    end

    it 'tambien crea tarea cuando la accion es todas' do
      regla = create(:regla_ambiental, club: club, accion: 'todas')
      expect { disparar(regla) }.to change(Tarea, :count).by(1)
    end

    it 'mapea la prioridad critica de la regla a urgente en la tarea' do
      regla = create(:regla_ambiental, club: club, accion: 'crear_tarea', prioridad: 'critica')
      disparar(regla)
      expect(Tarea.last.prioridad).to eq('urgente')
    end

    it 'asigna la tarea al responsable de la sala cuando existe' do
      cultivador = create(:user, :cultivador, club: club)
      sala.update!(responsable: cultivador)
      regla = create(:regla_ambiental, club: club, accion: 'crear_tarea')
      disparar(regla)
      expect(Tarea.last.asignada_a_id).to eq(cultivador.id)
    end

    it 'cae al admin del club como creador si la sala no tiene responsable' do
      regla = create(:regla_ambiental, club: club, accion: 'crear_tarea')
      disparar(regla)
      expect(Tarea.last.creada_por_id).to eq(admin.id)
    end
  end
end
