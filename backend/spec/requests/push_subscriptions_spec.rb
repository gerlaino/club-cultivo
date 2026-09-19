require 'rails_helper'

# Alta y baja de la suscripción push de UN dispositivo. La baja va por endpoint —el navegador
# no conoce el id—: con `resources … only: [:destroy]` la ruta pedía `/push_subscriptions/:id`,
# el frontend pegaba sin id, 404, y «desactivar» dejaba la suscripción viva mientras el toast
# decía lo contrario (19-sep-2026).
RSpec.describe 'Push subscriptions', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  before { sign_in_as(admin) }

  let(:datos) { { endpoint: 'https://push.example/abc', p256dh_key: 'p', auth_key: 'a', device_name: 'test' } }

  it 'da de alta el dispositivo' do
    post '/push_subscriptions', params: datos, headers: auth_headers, as: :json

    expect(response).to have_http_status(:created)
    expect(admin.push_subscriptions.active.pluck(:endpoint)).to eq(['https://push.example/abc'])
  end

  it 'da de baja por endpoint, sin id' do
    post '/push_subscriptions', params: datos, headers: auth_headers, as: :json

    delete '/push_subscriptions', params: { endpoint: 'https://push.example/abc' }, headers: auth_headers, as: :json

    expect(response).to have_http_status(:no_content)
    expect(admin.push_subscriptions.count).to eq(0)
  end

  it 'no toca la suscripción de otro usuario' do
    otro = create(:user, :cultivador, club: club)
    PushSubscription.create!(user: otro, club: club, endpoint: 'https://push.example/otro', p256dh_key: 'p', auth_key: 'a')

    delete '/push_subscriptions', params: { endpoint: 'https://push.example/otro' }, headers: auth_headers, as: :json

    expect(response).to have_http_status(:no_content)
    expect(otro.push_subscriptions.count).to eq(1)
  end
end
