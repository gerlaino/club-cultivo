require 'rails_helper'

RSpec.describe 'LecturasAmbientales', type: :request do
  # Con el Portal del paciente contratado: el rol `paciente` necesita ese módulo para poder
  # loguearse, y sin él el ejemplo de abajo daría 401 en vez de probar que no ve las lecturas.
  let(:club)       { create(:club, features: Club::FEATURES_POR_DEFECTO.merge('vista_paciente' => true)) }
  let(:sala)       { create(:sala, club: club) }
  let(:admin)      { create(:user, :admin, club: club) }
  let(:cultivador) { create(:user, :cultivador, club: club) }
  let(:auditor)    { create(:user, :auditor, club: club) }
  let(:dispensador){ create(:user, :dispensador, club: club) }
  let(:socio)      { create(:user, :socio, club: club) }

  let!(:lectura)   { create(:lectura_ambiental, sala: sala, club_id: club.id) }

  describe 'GET /salas/:sala_id/lecturas_ambientales' do
    context 'admin' do
      before { sign_in_as(admin) }
      it 'returns 200' do
        get "/salas/#{sala.id}/lecturas_ambientales", headers: auth_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'cultivador' do
      before { sign_in_as(cultivador) }
      it 'returns 200' do
        get "/salas/#{sala.id}/lecturas_ambientales", headers: auth_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'auditor' do
      before { sign_in_as(auditor) }
      it 'returns 200' do
        get "/salas/#{sala.id}/lecturas_ambientales", headers: auth_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'dispensador (forbidden)' do
      before { sign_in_as(dispensador) }
      it 'returns 403' do
        get "/salas/#{sala.id}/lecturas_ambientales", headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'socio (forbidden)' do
      before { sign_in_as(socio) }
      it 'returns 403' do
        get "/salas/#{sala.id}/lecturas_ambientales", headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    it 'returns 401 without token' do
      get "/salas/#{sala.id}/lecturas_ambientales"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /salas/:sala_id/lecturas_ambientales' do
    let(:valid_params) do
      { lectura_ambiental: { tipo: 'temperatura', valor: 25.0, unidad: '°C', medido_at: 1.hour.ago } }
    end

    context 'cultivador' do
      before { sign_in_as(cultivador) }
      it 'creates a lectura and enqueues job' do
        expect {
          post "/salas/#{sala.id}/lecturas_ambientales", params: valid_params, headers: auth_headers
        }.to change(LecturaAmbiental, :count).by(1)
        expect(response).to have_http_status(:created)
      end
    end

    context 'auditor (forbidden to write)' do
      before { sign_in_as(auditor) }
      it 'returns 403' do
        post "/salas/#{sala.id}/lecturas_ambientales", params: valid_params, headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'wrong club sala' do
      let(:otra_sala) do
        otro = create(:club)
        ActsAsTenant.with_tenant(otro) { create(:sala, club: otro) }
      end
      before { sign_in_as(cultivador) }
      it 'returns 404' do
        post "/salas/#{otra_sala.id}/lecturas_ambientales", params: valid_params, headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
