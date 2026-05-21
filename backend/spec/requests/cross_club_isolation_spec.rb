require 'rails_helper'

# Verifica que ningún usuario pueda acceder a datos de otro club.
# Cada contexto: usuario del club_b intenta leer un recurso del club_a.
RSpec.describe 'Cross-club isolation', type: :request do
  let!(:club_a) { create(:club) }
  let!(:club_b) { create(:club) }

  let!(:admin_a) { create(:user, :admin, club: club_a) }
  let!(:admin_b) { create(:user, :admin, club: club_b) }

  let!(:sala_a)    { create(:sala, club: club_a, created_by: admin_a) }
  let!(:lote_a)    { create(:lote, club: club_a, sala: sala_a) }
  let!(:sede_a)    { create(:sede, club: club_a, created_by: admin_a) }
  let!(:paciente_a) { create(:paciente, club: club_a, created_by: admin_a) }

  before { sign_in_as(admin_b) }

  # ── Salas ─────────────────────────────────────────────────
  describe 'GET /salas' do
    it 'does not include salas from another club' do
      get '/salas', headers: auth_headers
      ids = JSON.parse(response.body).map { |s| s['id'] }
      expect(ids).not_to include(sala_a.id)
    end
  end

  describe 'GET /salas/:id (club_a sala)' do
    it 'returns 404' do
      get "/salas/#{sala_a.id}", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ── Lotes ─────────────────────────────────────────────────
  describe 'GET /lotes' do
    it 'does not include lotes from another club' do
      get '/lotes', headers: auth_headers
      ids = JSON.parse(response.body).map { |l| l['id'] }
      expect(ids).not_to include(lote_a.id)
    end
  end

  describe 'GET /lotes/:id (club_a lote)' do
    it 'returns 404' do
      get "/lotes/#{lote_a.id}", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /lotes/:id (club_a lote)' do
    it 'returns 404' do
      patch "/lotes/#{lote_a.id}", params: { lote: { notes: 'hack' } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  # ── Pacientes ─────────────────────────────────────────────
  describe 'GET /pacientes' do
    it 'does not include pacientes from another club' do
      get '/pacientes', headers: auth_headers
      ids = (JSON.parse(response.body)['data'] || []).map { |p| p['id'] }
      expect(ids).not_to include(paciente_a.id)
    end
  end

  describe 'GET /pacientes/:id (club_a paciente)' do
    it 'returns 404' do
      get "/pacientes/#{paciente_a.id}", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /pacientes/:id (club_a paciente)' do
    it 'returns 404' do
      patch "/pacientes/#{paciente_a.id}", params: { paciente: { nombre: 'hack' } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  # ── Sedes ──────────────────────────────────────────────────
  describe 'GET /sedes' do
    it 'does not include sedes from another club' do
      get '/sedes', headers: auth_headers
      ids = JSON.parse(response.body).map { |s| s['id'] }
      expect(ids).not_to include(sede_a.id)
    end
  end

  describe 'GET /sedes/:id (club_a sede)' do
    it 'returns 404' do
      get "/sedes/#{sede_a.id}", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ── Salas anidadas bajo lotes y plantas ───────────────────
  describe 'GET /salas/:id/lotes (club_a sala)' do
    it 'returns 404' do
      get "/salas/#{sala_a.id}/lotes", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ── Dispensaciones anidadas bajo paciente de otro club ────
  describe 'GET /pacientes/:id/dispensaciones (club_a paciente)' do
    it 'returns 404' do
      get "/pacientes/#{paciente_a.id}/dispensaciones", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ── Genéticas ─────────────────────────────────────────────
  describe 'GET /geneticas' do
    let!(:genetica_a) { Genetica.create!(nombre: 'Test A Only', tipo: 'indica', club_id: club_a.id, global: false, activa: true) }
    let!(:genetica_global) { Genetica.where(global: true, registrada_inase: true).first || Genetica.create!(nombre: 'Global Test', tipo: 'hibrida', global: true, registrada_inase: true, club_id: nil, activa: true) }

    it 'includes global genetics but not club_a-specific ones' do
      get '/geneticas', headers: auth_headers
      ids = JSON.parse(response.body).map { |g| g['id'] }
      expect(ids).not_to include(genetica_a.id)
      expect(ids).to include(genetica_global.id)
    end
  end

  # ── Usuarios de otro club no son visibles ──────────────────
  describe 'GET /usuarios' do
    it 'does not include users from another club' do
      get '/usuarios', headers: auth_headers
      ids = (JSON.parse(response.body)['data'] || JSON.parse(response.body)).map { |u| u['id'] }
      expect(ids).not_to include(admin_a.id)
    end
  end
end
