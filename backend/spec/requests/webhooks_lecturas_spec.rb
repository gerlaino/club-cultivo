require 'rails_helper'

RSpec.describe 'Webhooks::Lecturas', type: :request do
  let(:club)        { create(:club) }
  let(:sala)        { create(:sala, club: club) }
  let(:dispositivo) { create(:dispositivo, sala: sala) }
  let(:valid_token) { dispositivo.regenerar_token! }

  describe 'POST /webhooks/lecturas' do
    let(:payload) do
      {
        dispositivo_id: dispositivo.id,
        tipo:           'temperatura',
        valor:          25.0,
        medido_at:      Time.current.iso8601
      }
    end

    it 'returns 202 with valid token' do
      post '/webhooks/lecturas',
           params: payload,
           headers: { 'X-Webhook-Token' => valid_token }
      expect(response).to have_http_status(:accepted)
    end

    it 'returns 401 with invalid token' do
      post '/webhooks/lecturas',
           params: payload,
           headers: { 'X-Webhook-Token' => 'bad_token' }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 401 without token' do
      post '/webhooks/lecturas', params: payload
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 401 for inactive dispositivo' do
      dispositivo.update!(estado: 'baja')
      post '/webhooks/lecturas',
           params: payload,
           headers: { 'X-Webhook-Token' => valid_token }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
