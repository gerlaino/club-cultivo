require 'rails_helper'

# AC (Germán, 6-oct-2026): «Pendiente de entrevista» = paciente con turno asignado con algún médico
# pero la consulta no se concretó, así administración puede apurar al médico. Se calcula solo: el
# turno ya pasó y el médico no lo cerró. Si el paciente FALTÓ (ausente), no es apurar al médico:
# va aparte como «Faltó al turno».
RSpec.describe 'Pendiente de entrevista / faltó al turno', type: :request do
  let(:club)   { create(:club) }
  let(:admin)  { create(:user, :admin, club: club) }
  let(:medico) { create(:user, :medico, club: club) }

  def paciente(apellido)
    create(:paciente, club: club, created_by: admin, apellido: apellido)
  end

  def turno(p, cuando:, estado:, medico: self.medico)
    ActsAsTenant.with_tenant(club) do
      Turno.create!(club: club, paciente: p, medico: medico, fecha_hora: cuando,
                    duracion_minutos: 30, tipo: 'seguimiento', estado: estado)
    end
  end

  def entrevista_por_apellido
    get '/api/pacientes'
    JSON.parse(response.body)['data'].to_h { |p| [p['apellido'], p['entrevista']] }
  end

  before { sign_in_as(admin) }

  it 'sólo el paciente cuyo turno ya pasó sin cerrarse queda pendiente de entrevista' do
    atrasado = paciente('Atrasado')
    a_tiempo = paciente('ATiempo')
    atendido = paciente('Atendido')
    paciente('SinTurno')
    turno(atrasado, cuando: 2.days.ago,       estado: 'confirmado')
    turno(a_tiempo, cuando: 2.days.from_now,  estado: 'programado')
    turno(atendido, cuando: 3.days.ago,       estado: 'realizado')

    expect(entrevista_por_apellido).to eq(
      'Atrasado' => 'pendiente_entrevista', 'ATiempo' => nil, 'Atendido' => nil, 'SinTurno' => nil
    )
  end

  it 'deja de estar pendiente cuando el médico marca el turno realizado' do
    p = paciente('Atrasado')
    t = turno(p, cuando: 1.day.ago, estado: 'programado')
    t.update!(estado: 'realizado')
    expect(entrevista_por_apellido['Atrasado']).to be_nil
  end

  it 'si el paciente faltó, no es pendiente de entrevista sino «faltó al turno»' do
    p = paciente('Falto')
    turno(p, cuando: 1.day.ago, estado: 'ausente')
    expect(entrevista_por_apellido['Falto']).to eq('falto_turno')
  end

  it 'el que faltó pero ya tiene otro turno dado no aparece como que faltó' do
    p = paciente('Reprogramado')
    turno(p, cuando: 3.days.ago,      estado: 'ausente')
    turno(p, cuando: 2.days.from_now, estado: 'programado')
    expect(entrevista_por_apellido['Reprogramado']).to be_nil
  end

  it 'la ficha lo dice' do
    p = paciente('Atrasado')
    turno(p, cuando: 2.days.ago, estado: 'programado')
    get "/api/pacientes/#{p.id}"
    expect(JSON.parse(response.body)['data']['entrevista']).to eq('pendiente_entrevista')
  end

  it 'administración ve, por médico, cuántos turnos ya pasaron sin cerrar' do
    otro = create(:user, :medico, club: club)
    turno(paciente('A'), cuando: 2.days.ago, estado: 'programado')
    turno(paciente('B'), cuando: 1.day.ago,  estado: 'confirmado')
    turno(paciente('C'), cuando: 1.day.ago,  estado: 'realizado')
    turno(paciente('D'), cuando: 1.day.ago,  estado: 'programado', medico: otro)

    get '/api/admin/medicos'
    sin_cerrar = JSON.parse(response.body).to_h { |m| [m['id'], m['turnos_sin_cerrar']] }
    expect(sin_cerrar).to eq(medico.id => 2, otro.id => 1)
  end

  it 'el mostrador no lo recibe (no es asunto suyo, como el REPROCANN)' do
    p = paciente('Atrasado')
    turno(p, cuando: 2.days.ago, estado: 'programado')
    sign_in_as(create(:user, :dispensador, club: club))
    get '/api/pacientes'
    expect(JSON.parse(response.body)['data'].first['entrevista']).to be_nil
  end
end
