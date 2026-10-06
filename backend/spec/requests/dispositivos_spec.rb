require 'rails_helper'

RSpec.describe 'Dispositivos', type: :request do
  let(:club)       { create(:club) }
  before { club.update_columns(features: club.features.merge('iot' => true)) }
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

      # Lo que la pantalla muestra para copiar en el sensor (URL + token) tiene que servir tal cual:
      # el cartel de alta armaba `/api/webhooks/lecturas/:id`, que no existe, y el sensor nunca
      # mandaba nada.
      it 'la URL y el token que devuelve reciben lecturas tal cual se copian' do
        post "/dispositivos/#{dispositivo.id}/regenerar_token", headers: auth_headers
        body = response.parsed_body

        post body['webhook_url'],
             params:  { tipo: 'temperatura', valor: 24.5, medido_at: Time.current.iso8601 },
             headers: { 'X-Webhook-Token' => body['token'] }
        expect(response).to have_http_status(:accepted)
      end

      it 'la lista de sensores trae la misma URL' do
        post "/dispositivos/#{dispositivo.id}/regenerar_token", headers: auth_headers
        url = response.parsed_body['webhook_url']

        get '/dispositivos', headers: auth_headers
        expect(response.parsed_body.find { |d| d['id'] == dispositivo.id }['webhook_url']).to eq(url)
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
