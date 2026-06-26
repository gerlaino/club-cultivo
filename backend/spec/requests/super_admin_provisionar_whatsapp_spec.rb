require 'rails_helper'

RSpec.describe 'PATCH /super_admin/clubs/:id/provisionar_whatsapp', type: :request do
  include AuthHelpers

  let(:club)  { create(:club, whatsapp_numero: '+5491112345678') }
  let(:sa)    { create(:user, :super_admin) }

  before { sign_in_as(sa) }

  it 'carga las credenciales de Twilio y deja el club conectado' do
    patch "/super_admin/clubs/#{club.id}/provisionar_whatsapp",
          params: { twilio_account_sid: 'AC123', twilio_auth_token: 'tok-secreto', twilio_whatsapp_from: '+14155238886' },
          headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body['whatsapp_estado']).to eq('conectado')
    expect(body['twilio_whatsapp_from']).to eq('whatsapp:+14155238886') # normalizado

    club.reload
    expect(club.twilio_configurado?).to be true
    expect(club.twilio_auth_token).to eq('tok-secreto') # se guarda cifrado y se recupera
  end

  it 'exige el Auth Token la primera vez' do
    patch "/super_admin/clubs/#{club.id}/provisionar_whatsapp",
          params: { twilio_account_sid: 'AC123', twilio_whatsapp_from: '+14155238886' },
          headers: auth_headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'desconectar limpia las credenciales' do
    club.update!(twilio_account_sid: 'AC1', twilio_whatsapp_from: 'whatsapp:+1')
    club.twilio_auth_token = 'tok'; club.save!
    delete "/super_admin/clubs/#{club.id}/desconectar_whatsapp", headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(club.reload.twilio_configurado?).to be false
  end
end
