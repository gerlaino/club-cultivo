require 'rails_helper'

RSpec.describe 'Webhooks::Lecturas', type: :request do
  let(:club)        { create(:club) }
  # El add-on IoT no viene por defecto y la ingesta ahora lo exige: un club que no tiene el
  # módulo no debe seguir alimentando lecturas, reglas y alertas que nadie puede ver.
  before { club.update_columns(features: club.features.merge('iot' => true)) }
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

    # El sensor sigue posteando aunque el club se haya bajado del módulo: nadie desenchufa el
    # hardware. Se rechaza con 403 (no 401: el token es válido) y no se ingiere nada.
    it 'returns 403 when the club turned IoT off' do
      token = valid_token
      club.update_columns(features: club.features.merge('iot' => false))

      expect {
        post '/webhooks/lecturas', params: payload, headers: { 'X-Webhook-Token' => token }
      }.not_to change(LecturaAmbiental, :count)

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns 403 when the club is suspended' do
      token = valid_token
      club.suspender!

      post '/webhooks/lecturas', params: payload, headers: { 'X-Webhook-Token' => token }
      expect(response).to have_http_status(:forbidden)
    end
  end
end
