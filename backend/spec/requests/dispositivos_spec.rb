require 'rails_helper'

RSpec.describe 'Dispositivos', type: :request do
  let(:club)       { create(:club) }
  let(:sala)       { create(:sala, club: club) }
  let(:admin)      { create(:user, :admin, club: club) }
  let(:cultivador) { create(:user, :cultivador, club: club) }
  let(:auditor)    { create(:user, :auditor, club: club) }
  let(:dispensador){ create(:user, :dispensador, club: club) }

  let!(:dispositivo) { create(:dispositivo, club: club, sala: sala) }

  describe 'GET /dispositivos' do
    context 'admin' do
      before { sign_in_as(admin) }
      it 'returns 200' do
        get '/dispositivos', headers: auth_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'cultivador (forbidden — admin only)' do
      before { sign_in_as(cultivador) }
      it 'returns 403' do
        get '/dispositivos', headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'auditor (forbidden)' do
      before { sign_in_as(auditor) }
      it 'returns 403' do
        get '/dispositivos', headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'dispensador (forbidden)' do
      before { sign_in_as(dispensador) }
      it 'returns 403' do
        get '/dispositivos', headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'sin token' do
      it 'returns 401' do
        get '/dispositivos'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /dispositivos/:id/regenerar_token' do
    context 'admin' do
      before { sign_in_as(admin) }
      it 'returns a plain token' do
        post "/dispositivos/#{dispositivo.id}/regenerar_token", headers: auth_headers
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['token']).to be_present
        expect(body['token'].length).to eq(64)
      end
    end

    context 'cultivador (forbidden)' do
      before { sign_in_as(cultivador) }
      it 'returns 403' do
        post "/dispositivos/#{dispositivo.id}/regenerar_token", headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'dispositivo from another club' do
      let(:otro) do
        otro_club = create(:club)
        ActsAsTenant.with_tenant(otro_club) { create(:dispositivo, sala: create(:sala, club: otro_club)) }
      end
      before { sign_in_as(admin) }
      it 'returns 404' do
        post "/dispositivos/#{otro.id}/regenerar_token", headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
