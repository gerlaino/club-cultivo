require 'rails_helper'

# AC: el paciente NO es parte del equipo.
#
# Tiene un `User` porque necesita entrar a su portal, no porque trabaje en la organización.
# La pantalla Equipo (`/equipo` → `/usuarios`) listaba a todos los usuarios del club, así que
# cuanto más se vendía el portal del paciente, más se llenaba de padrón.
RSpec.describe 'GET /usuarios (Equipo) — el paciente no es equipo', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, club: club, role: 'admin') }

  before { sign_in_as(admin) }

  def ids_listados
    get '/usuarios', headers: auth_headers
    expect(response).to have_http_status(:ok)
    JSON.parse(response.body)['data'].map { |u| u['id'] }
  end

  it 'no lista la cuenta de portal de un paciente' do
    paciente = create(:user, club: club, role: 'paciente')

    expect(ids_listados).to include(admin.id)
    expect(ids_listados).not_to include(paciente.id)
  end

  it 'sigue listando a los operativos' do
    cultivador = create(:user, club: club, role: 'cultivador')

    expect(ids_listados).to include(cultivador.id)
  end

  # El filtro por rol no es una puerta de atrás: el índice de equipo nunca devuelve pacientes,
  # ni aunque los pidan explícitamente.
  it 'no los devuelve ni pidiéndolos por rol' do
    create(:user, club: club, role: 'paciente')

    get '/usuarios', params: { role: 'paciente' }, headers: auth_headers
    expect(JSON.parse(response.body)['data']).to be_empty
  end

  it 'no muestra pacientes de otra organización' do
    otro = create(:club)
    ajeno = create(:user, club: otro, role: 'cultivador')

    expect(ids_listados).not_to include(ajeno.id)
  end

  describe 'los endpoints de equipo sobre una cuenta de paciente' do
    # Se gestiona desde la ficha del paciente (`Pacientes::Acceso`), nunca desde acá: por API,
    # un admin podía resetearle la clave o BORRARLE la cuenta, dejando el `paciente.user_id`
    # colgado.
    let!(:paciente) { create(:user, club: club, role: 'paciente') }

    it 'no la deja ver' do
      get "/usuarios/#{paciente.id}", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it 'no la deja borrar' do
      expect {
        delete "/usuarios/#{paciente.id}", headers: auth_headers
      }.not_to change(User, :count)
      expect(response).to have_http_status(:not_found)
    end

    it 'no le deja resetear la contraseña' do
      post "/usuarios/#{paciente.id}/reset_password", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
