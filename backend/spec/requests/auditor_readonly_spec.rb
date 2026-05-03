require 'rails_helper'

RSpec.describe 'Auditor write-block', type: :request do
  let!(:club)    { create(:club) }
  let!(:auditor) { create(:user, :auditor, club: club) }
  let!(:admin)   { create(:user, :admin,   club: club) }

  let!(:sede)    { create(:sede,   club: club, created_by: admin) }
  let!(:sala)    { create(:sala,   club: club, created_by: admin, sede: sede) }
  let!(:lote)    { create(:lote,   club: club, sala: sala) }
  let!(:paciente){ create(:paciente, club: club, created_by: admin) }

  before { sign_in_as(auditor) }

  context 'Ola 5: GET directos ahora retornan 403 (auditor usa /informes)' do
    it 'GET /pacientes → 403' do
      get '/pacientes', headers: auth_headers
      expect(response).to have_http_status(:forbidden)
    end

    it 'GET /salas → 403 (cultivador/manicura only)' do
      get '/salas', headers: auth_headers
      expect(response).to have_http_status(:forbidden)
    end

    it 'GET /lotes → 403' do
      get '/lotes', headers: auth_headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'mutating requests are forbidden' do
    it 'POST /pacientes → 403' do
      post '/pacientes', params: { paciente: { nombre: 'Hack', apellido: 'Test', dni: '99999999' } },
           headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'PATCH /pacientes/:id → 403' do
      patch "/pacientes/#{paciente.id}", params: { paciente: { nombre: 'Hackeado' } },
            headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'DELETE /pacientes/:id → 403' do
      delete "/pacientes/#{paciente.id}", headers: auth_headers
      expect(response).to have_http_status(:forbidden)
    end

    it 'POST /salas → 403' do
      post '/salas', params: { sala: { nombre: 'Hack', club_id: club.id } },
           headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'PATCH /salas/:id → 403' do
      patch "/salas/#{sala.id}", params: { sala: { nombre: 'Hackeada' } },
            headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'POST /salas/:id/lotes → 403' do
      post "/salas/#{sala.id}/lotes", params: { lote: { codigo: 'HACK-01' } },
           headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'PATCH /lotes/:id → 403' do
      patch "/lotes/#{lote.id}", params: { lote: { notas: 'hackeado' } },
            headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'POST /pacientes/:id/notas → 403' do
      post "/pacientes/#{paciente.id}/notas",
           params: { nota: { contenido: 'nota falsa' } },
           headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end
end
