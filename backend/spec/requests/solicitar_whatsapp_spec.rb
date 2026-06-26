require 'rails_helper'

RSpec.describe 'PATCH /preferences/solicitar_whatsapp', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  before { sign_in_as(admin) }

  it 'guarda el número y deja el WhatsApp en estado pendiente' do
    patch '/preferences/solicitar_whatsapp', params: { numero: '+54 11 1234-5678' }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body['whatsapp_numero']).to eq('+54 11 1234-5678')
    expect(body['whatsapp_estado']).to eq('pendiente')
    expect(club.reload.whatsapp_numero).to eq('+54 11 1234-5678')
  end

  it 'pide el número' do
    patch '/preferences/solicitar_whatsapp', params: { numero: '' }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'el estado es sin_configurar cuando no hay nada' do
    expect(club.whatsapp_estado).to eq('sin_configurar')
  end
end
