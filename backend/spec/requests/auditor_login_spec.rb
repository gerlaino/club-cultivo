require 'rails_helper'

RSpec.describe 'Auditor login', type: :request do
  let!(:club)    { create(:club) }
  let!(:auditor) { create(:user, :auditor, club: club) }
  let!(:admin)   { create(:user, :admin,   club: club) }
  let!(:sede)    { create(:sede, club: club, created_by: admin) }
  let!(:sala)    { create(:sala, club: club, created_by: admin, sede: sede) }
  let!(:paciente){ create(:paciente, club: club, created_by: admin) }

  it 'POST /users/sign_in → 200 with JWT' do
    post '/users/sign_in',
         params: { user: { email: auditor.email, password: 'password123' } },
         as: :json
    expect(response).to have_http_status(:ok)
    expect(response.headers['Authorization']).to be_present
  end

  context 'after login (Ola 5: auditor usa /informes, no rutas directas)' do
    before { sign_in_as(auditor) }

    it 'GET /pacientes → 403 (usar /informes/reprocann)' do
      get '/pacientes', headers: auth_headers
      expect(response).to have_http_status(:forbidden)
    end

    it 'GET /lotes → 403 (usar /informes/produccion)' do
      get '/lotes', headers: auth_headers
      expect(response).to have_http_status(:forbidden)
    end

    it 'GET /informes/reprocann → 200' do
      get '/informes/reprocann', headers: auth_headers
      expect(response).to have_http_status(:ok)
    end

    it 'POST /lotes via sala → 403 (write blocked)' do
      post "/salas/#{sala.id}/lotes",
           params: { lote: { codigo: 'HACK-01' } },
           headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'PATCH /pacientes/:id → 403 (write blocked)' do
      patch "/pacientes/#{paciente.id}",
            params: { paciente: { nombre: 'Hackeado' } },
            headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end
end
