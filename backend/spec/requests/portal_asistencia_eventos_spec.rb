require 'rails_helper'

# «ASISTIRÉ» EN LOS EVENTOS DEL PORTAL (27-oct-2026).
#
# AC: el paciente marca que va a un evento próximo (y puede desmarcarlo); la organización ve
# cuántos y quiénes van. El paciente ve si él va, NO cuántos ni quiénes. Un evento pasado no se
# marca; otra organización no ve a los asistentes.
RSpec.describe 'Portal — Asistiré', type: :request do
  include AuthHelpers

  let(:club) do
    create(:club, vista_paciente_activa: true, features: { 'produccion_dispensa' => true, 'vista_paciente' => true })
  end
  let(:admin)  { create(:user, :admin, club: club) }
  let(:evento) { Evento.create!(club: club, titulo: 'Taller: cultivar en casa', fecha_inicio: 10.days.from_now, activo: true) }

  def paciente_con_cuenta(nombre)
    p = create(:paciente, club: club, nombre: nombre, apellido: 'Test', created_by: admin, aprobado_at: Time.current)
    u = Pacientes::Acceso.crear!(p).user
    u.update!(password: AuthHelpers::DEFAULT_PASSWORD, password_confirmation: AuthHelpers::DEFAULT_PASSWORD)
    [p, u]
  end

  def json = JSON.parse(response.body)['data']

  it 'marca que va, lo ve marcado, y la organización ve quién va' do
    _lucia, user = paciente_con_cuenta('Lucía')
    sign_in_as(user)

    post "/api/portal/eventos/#{evento.id}/asistencia"
    expect(response).to have_http_status(:ok), response.body
    get '/api/portal/eventos'
    expect(json.first).to include('id' => evento.id, 'asistire' => true)

    sign_in_as(admin)
    get '/api/eventos'
    expect(json.find { |e| e['id'] == evento.id }['asistentes']).to eq(1)
    get "/api/eventos/#{evento.id}/asistentes"
    expect(json.map { |a| a['nombre'] }).to eq(['Lucía Test'])
  end

  it 'marcar dos veces no duplica; desmarcar lo saca' do
    _p, user = paciente_con_cuenta('Lucía')
    sign_in_as(user)
    2.times { post "/api/portal/eventos/#{evento.id}/asistencia" }
    expect(evento.asistencias.count).to eq(1)

    delete "/api/portal/eventos/#{evento.id}/asistencia"
    expect(json['asistire']).to be(false)
    expect(evento.asistencias.count).to eq(0)
  end

  it 'el paciente no ve cuántos ni quiénes van' do
    _a, ua = paciente_con_cuenta('Ana')
    _b, ub = paciente_con_cuenta('Bea')
    sign_in_as(ua)
    post "/api/portal/eventos/#{evento.id}/asistencia"
    sign_in_as(ub)

    get "/api/portal/eventos/#{evento.id}"
    expect(response.body).not_to include('Ana')
    expect(json.keys).not_to include('asistentes')
    get "/api/eventos/#{evento.id}/asistentes"
    expect(response.status).to be_in([401, 403])
  end

  it 'un evento que ya pasó no se marca' do
    pasado = Evento.create!(club: club, titulo: 'Viejo', fecha_inicio: 2.days.ago, activo: true)
    _p, user = paciente_con_cuenta('Lucía')
    sign_in_as(user)

    post "/api/portal/eventos/#{pasado.id}/asistencia"
    expect(response).to have_http_status(:not_found)
  end

  it 'otra organización no ve a los asistentes' do
    _p, user = paciente_con_cuenta('Lucía')
    sign_in_as(user)
    post "/api/portal/eventos/#{evento.id}/asistencia"

    otra = create(:club, features: { 'produccion_dispensa' => true })
    sign_in_as(create(:user, :admin, club: otra))
    get "/api/eventos/#{evento.id}/asistentes"
    expect(response).to have_http_status(:not_found)
  end
end
