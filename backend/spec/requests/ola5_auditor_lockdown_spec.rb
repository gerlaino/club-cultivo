require 'rails_helper'

RSpec.describe 'Ola 5 — Auditor lockdown (rework)', type: :request do
  let(:club)    { create(:club) }
  let(:admin)   { create(:user, :admin,   club: club) }
  let(:auditor) { create(:user, :auditor, club: club) }

  let!(:sede)    { create(:sede, club: club, created_by: admin) }
  let!(:sala)    { create(:sala, club: club, sede: sede, created_by: admin) }
  let!(:lote)    { create(:lote, club: club, sala: sala) }
  let!(:paciente){ create(:paciente, club: club, created_by: admin) }

  before { sign_in_as(auditor) }

  context 'acceso bloqueado — rutas directas' do
    it 'GET /pacientes → 403' do
      get '/pacientes', headers: auth_headers
      expect(response).to have_http_status(:forbidden)
    end

    it 'GET /lotes → 403' do
      get '/lotes', headers: auth_headers
      expect(response).to have_http_status(:forbidden)
    end

    it 'GET /stocks → 403' do
      get '/stocks', headers: auth_headers
      expect(response).to have_http_status(:forbidden)
    end

    it 'GET /sedes → 403' do
      get '/sedes', headers: auth_headers
      expect(response).to have_http_status(:forbidden)
    end

    it 'GET /dispensaciones → 403' do
      get '/dispensaciones', headers: auth_headers
      expect(response).to have_http_status(:forbidden)
    end

    it 'GET /documentos → 403' do
      get '/documentos', headers: auth_headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'acceso permitido — informes' do
    it 'GET /informes/reprocann → 200' do
      get '/informes/reprocann', headers: auth_headers
      expect(response).to have_http_status(:ok)
    end

    it 'GET /informes/produccion → 200' do
      get '/informes/produccion', headers: auth_headers
      expect(response).to have_http_status(:ok)
    end
  end
end
