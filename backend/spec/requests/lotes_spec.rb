require 'rails_helper'

RSpec.describe 'POST /lotes/:id/avanzar_fase', type: :request do
  let(:club)       { create(:club) }
  let(:sede)       { create(:sede, club: club) }
  let(:sala)       { create(:sala, club: club, sede: sede) }
  let(:cultivador) { u = create(:user, :cultivador, club: club); u.sedes_asignadas << sede; u }
  let(:manicura)   { create(:user, club: club, role: 'manicura') }
  let(:admin)      { create(:user, club: club, role: 'admin') }

  let(:lote_floracion) { create(:lote, club: club, sala: sala, estado: 'floracion') }
  let(:lote_cosecha)   { create(:lote, club: club, sala: sala, estado: 'cosecha') }
  let(:lote_secado)    { create(:lote, club: club, sala: sala, estado: 'secado') }
  let(:lote_curado)    { create(:lote, club: club, sala: sala, estado: 'curado') }

  context 'cultivador del mismo club — lote en floracion (→ cosecha)' do
    before { sign_in_as(cultivador) }

    it 'devuelve 422 — floracion→cosecha debe ir por el endpoint de transiciones con datos de pesada' do
      post "/lotes/#{lote_floracion.id}/avanzar_fase", headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to include('cosecha')
    end
  end

  context 'cultivador del mismo club — lote en cosecha (→ secado)' do
    before { sign_in_as(cultivador) }

    it 'devuelve 200 y el lote pasa a secado' do
      post "/lotes/#{lote_cosecha.id}/avanzar_fase", headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['estado']).to eq('secado')
    end
  end

  context 'manicura — lote en cosecha (fuera de scope)' do
    before { sign_in_as(manicura) }

    it 'devuelve 404 (cosecha no está en scope de manicura)' do
      post "/lotes/#{lote_cosecha.id}/avanzar_fase", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'manicura — lote en secado (→ manicura_pendiente vía pesada, no avanzar_fase)' do
    before { sign_in_as(manicura) }

    it 'devuelve 403 (avanzar_fase ya no aplica a manicura para secado)' do
      post "/lotes/#{lote_secado.id}/avanzar_fase", headers: auth_headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'manicura — lote en floracion (fuera de scope)' do
    before { sign_in_as(manicura) }

    it 'devuelve 404 — lote en floracion invisible para manicura' do
      post "/lotes/#{lote_floracion.id}/avanzar_fase", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'cultivador — lote en curado (ya cerrar_curado, no avanzar_fase)' do
    before { sign_in_as(cultivador) }

    it 'devuelve 403 — cultivador no puede avanzar desde curado' do
      post "/lotes/#{lote_curado.id}/avanzar_fase", headers: auth_headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'cultivador de otro club' do
    let(:otro_club)       { create(:club) }
    let(:otro_cultivador) { create(:user, :cultivador, club: otro_club) }
    before { sign_in_as(otro_cultivador) }

    it 'devuelve 404 (lote de otro club no existe para este usuario)' do
      post "/lotes/#{lote_floracion.id}/avanzar_fase", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
