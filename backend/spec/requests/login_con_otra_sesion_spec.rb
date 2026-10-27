require 'rails_helper'

# AC (27-oct-2026): entrar con el usuario y la clave de B deja adentro a B, aunque el navegador
# todavía tenga la sesión de A. Devise/Warden devolvía al que ya estaba en la sesión de Rails e
# ignoraba lo que se escribió: se entraba con la cuenta de otra persona.
RSpec.describe 'Entrar habiendo otra sesión abierta', type: :request do
  include AuthHelpers

  let(:club) { create(:club, features: { 'produccion_dispensa' => true }) }
  let(:a) { create(:user, :admin, club: club, email: 'a@org.test') }
  let(:b) { create(:user, :dispensador, club: club, email: 'b@org.test') }

  def quien_soy
    get '/api/me'
    body = JSON.parse(response.body)
    body['email'] || body.dig('user', 'email')
  end

  it 'con las credenciales de B entra B, no el que estaba' do
    sign_in_as(a)
    expect(quien_soy).to eq('a@org.test')

    post '/api/users/sign_in', params: { user: { email: b.email, password: AuthHelpers::DEFAULT_PASSWORD } }, as: :json

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['email']).to eq('b@org.test')
    expect(quien_soy).to eq('b@org.test')
  end

  it 'con una clave equivocada no queda adentro nadie nuevo' do
    sign_in_as(a)
    post '/api/users/sign_in', params: { user: { email: b.email, password: 'mal' } }, as: :json
    expect(response).to have_http_status(:unauthorized)
  end
end
