require 'rails_helper'

# AC: las reglas de ambiente son del módulo IoT. Sin el módulo no se crean ni se ven.
#
# La pantalla ya lo escondía —`/reglas-ambientales` pide `iot` en el router— y el backend no, así
# que por API una organización sin IoT las creaba igual. Es el patrón que más nos rompió cosas:
# la regla escrita en un solo lado, y justo el lado que se saltea.
RSpec.describe 'Reglas ambientales: el módulo IoT', type: :request do
  include AuthHelpers

  let(:admin) { create(:user, :admin, club: club) }

  before { sign_in_as(admin) }

  context 'sin el módulo' do
    let(:club) { create(:club, features: { 'cultivo' => true }) }

    it 'no las lista' do
      get '/api/reglas_ambientales'

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['modulo']).to eq('iot')
    end

    it 'no deja crearlas por API' do
      post '/api/reglas_ambientales',
           params: { regla_ambiental: { nombre: 'Calor', metrica: 'temperatura', operador: '>', valor: 30 } },
           as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'con el módulo' do
    let(:club) { create(:club, features: { 'cultivo' => true, 'iot' => true }) }

    it 'las lista' do
      get '/api/reglas_ambientales'

      expect(response).to have_http_status(:ok), response.body
    end
  end
end
