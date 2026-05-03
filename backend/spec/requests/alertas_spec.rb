require 'rails_helper'

RSpec.describe 'Alertas', type: :request do
  let(:club)       { create(:club) }
  let(:sala)       { create(:sala, club: club) }
  let(:admin)      { create(:user, :admin, club: club) }
  let(:cultivador) { create(:user, :cultivador, club: club) }
  let(:auditor)    { create(:user, :auditor, club: club) }
  let(:dispensador){ create(:user, :dispensador, club: club) }

  let!(:alerta)    { create(:alerta, sala: sala, club_id: club.id) }

  describe 'GET /alertas' do
    context 'admin' do
      before { sign_in_as(admin) }
      it 'returns 200 with alerts' do
        get '/alertas', headers: auth_headers
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body).length).to be >= 1
      end
    end

    context 'cultivador' do
      before { sign_in_as(cultivador) }
      it 'returns 200' do
        get '/alertas', headers: auth_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'auditor' do
      before { sign_in_as(auditor) }
      it 'returns 200 (read-only access)' do
        get '/alertas', headers: auth_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'dispensador (forbidden)' do
      before { sign_in_as(dispensador) }
      it 'returns 403' do
        get '/alertas', headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    it 'returns 401 without token' do
      get '/alertas'
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /alertas/:id/reconocer' do
    context 'cultivador' do
      before { sign_in_as(cultivador) }
      it 'transitions alert to reconocida' do
        post "/alertas/#{alerta.id}/reconocer", headers: auth_headers
        expect(response).to have_http_status(:ok)
        expect(alerta.reload.estado).to eq('reconocida')
      end
    end

    context 'auditor (forbidden to write)' do
      before { sign_in_as(auditor) }
      it 'returns 403' do
        post "/alertas/#{alerta.id}/reconocer", headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'alert from another club' do
      let(:otra_alerta) { create(:alerta) }
      before { sign_in_as(cultivador) }
      it 'returns 404' do
        post "/alertas/#{otra_alerta.id}/reconocer", headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /alertas/:id/resolver' do
    context 'admin' do
      before { sign_in_as(admin) }
      it 'resolves the alert' do
        post "/alertas/#{alerta.id}/resolver", headers: auth_headers
        expect(response).to have_http_status(:ok)
        expect(alerta.reload.estado).to eq('resuelta')
      end
    end
  end
end
