require 'rails_helper'

# AC (Germán, 19-oct-2026): «no pueden haber dos turnos en el mismo horario» para el mismo médico.
RSpec.describe 'Turnos superpuestos del mismo médico', type: :request do
  let(:club)   { create(:club) }
  let(:admin)  { create(:user, :admin, club: club) }
  let(:medico) { create(:user, :medico, club: club) }
  let(:otro_medico) { create(:user, :medico, club: club) }
  let(:a) { create(:paciente, club: club, created_by: admin) }
  let(:b) { create(:paciente, club: club, created_by: admin) }
  let(:manana) { (Time.zone.today + 2).in_time_zone.change(hour: 10) }

  before { sign_in_as(admin) }

  def dar(paciente, cuando, m = medico, duracion: 30)
    post "/api/admin/medicos/#{m.id}/crear_turno",
         params: { turno: { paciente_id: paciente.id, fecha_hora: cuando.iso8601, duracion_minutos: duracion, tipo: 'seguimiento' } }
  end

  it 'rechaza el mismo horario y el que se pisa a medias, con el motivo' do
    dar(a, manana)
    expect(response).to have_http_status(:created)

    dar(b, manana)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['errors'].join).to match(/ya tiene un turno a las 10:00/)

    dar(b, manana + 15.minutes)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(Turno.count).to eq(1)
  end

  it 'deja el turno pegado (10:30 después de uno de 10:00 a 10:30)' do
    dar(a, manana)
    dar(b, manana + 30.minutes)
    expect(response).to have_http_status(:created)
  end

  it 'otro médico en el mismo horario sí puede' do
    dar(a, manana)
    dar(b, manana, otro_medico)
    expect(response).to have_http_status(:created)
  end

  it 'un turno cancelado libera el horario' do
    dar(a, manana)
    Turno.last.update!(estado: 'cancelado')
    dar(b, manana)
    expect(response).to have_http_status(:created)
  end

  it 'el alta con turno tampoco se superpone, y no deja el paciente a medias' do
    dar(a, manana)
    expect {
      post '/api/pacientes', params: { paciente: { nombre: 'Ana', apellido: 'Paz', dni: '30111222', fecha_nacimiento: '1990-01-01' },
                                       turno: { medico_id: medico.id, fecha_hora: manana.iso8601 } }
    }.not_to change(Paciente, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'reprogramar encima de otro turno se rechaza' do
    dar(a, manana)
    dar(b, manana + 2.hours)
    t = Turno.find_by(paciente: b)
    patch "/api/admin/turnos/#{t.id}", params: { turno: { fecha_hora: manana.iso8601 } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(t.reload.fecha_hora).to eq(manana + 2.hours)
  end
end
