require 'rails_helper'

# AC: ningún alta nace con una contraseña que se pueda adivinar.
#
# Hasta el 20-ago existía `Club::PASSWORD_DEFAULT = ENV.fetch('CLUB_DEFAULT_PASSWORD', '123456Aa')`.
# La variable de entorno no estaba puesta, así que **todo usuario creado desde el panel de
# plataforma nacía con `123456Aa`** — y el formulario del super admin encima la traía precargada,
# de modo que ni siquiera hacía falta que alguien la eligiera. Sabiendo el email de cualquiera se
# entraba a su club.
#
# Ahora cada alta genera la suya con `User.password_temporal`, que ya existía para el "restablecer"
# y arma una clave DICTABLE por teléfono (sin 0/O ni 1/l/I). El endpoint la devuelve en claro a
# propósito: es temporal, hay que poder dictarla, y Devise pide cambiarla al entrar.
RSpec.describe 'La contraseña inicial se genera, no es fija', type: :request do
  let(:super_admin) { create(:user, :super_admin) }
  let(:club)        { create(:club) }

  before { sign_in_as(super_admin) }

  VIEJA = '123456Aa'.freeze

  describe 'un usuario creado desde el panel de plataforma' do
    def crear!(password: nil)
      post '/super_admin/users',
           params: { user: { email: "nuevo#{rand(10_000)}@club.com", role: 'admin',
                             club_id: club.id, password: password }.compact },
           headers: auth_headers
    end

    it 'sin contraseña escrita, no queda con la vieja' do
      crear!

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['password_inicial']).to be_present
      expect(body['password_inicial']).not_to eq(VIEJA)
      expect(User.find(body['id']).valid_password?(VIEJA)).to be(false)
    end

    it 'devuelve la generada para poder dictarla, y sirve para entrar' do
      crear!

      body = JSON.parse(response.body)
      expect(User.find(body['id']).valid_password?(body['password_inicial'])).to be(true)
    end

    # Dos altas seguidas no pueden compartir clave: si compartieran, seguiría siendo una fija.
    it 'genera una distinta por usuario' do
      crear!
      primera = JSON.parse(response.body)['password_inicial']
      crear!
      segunda = JSON.parse(response.body)['password_inicial']

      expect(primera).not_to eq(segunda)
    end

    it 'si el super admin escribe una, se respeta' do
      crear!(password: 'ElegidaAMano9')

      expect(User.find(JSON.parse(response.body)['id']).valid_password?('ElegidaAMano9')).to be(true)
    end
  end

  describe 'los usuarios que nacen con una organización nueva' do
    it 'no quedan con la vieja, y la generada se devuelve para dictarla' do
      post '/super_admin/clubs',
           params: { club: { name: 'Nueva Org', email: 'org@nueva.com' }, roles_a_crear: ['admin'] },
           headers: auth_headers

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['password_inicial']).to be_present
      expect(body['password_inicial']).not_to eq(VIEJA)

      admin = User.find_by(email: body['usuarios'].first['email'])
      expect(admin.valid_password?(VIEJA)).to be(false)
      expect(admin.valid_password?(body['password_inicial'])).to be(true)
    end
  end

  # El panel usaba este dato para PRECARGAR el campo del formulario. Mientras viaje, hay una
  # credencial de plataforma publicada en un endpoint.
  it 'el catálogo ya no publica una contraseña por defecto' do
    get '/super_admin/catalogo', headers: auth_headers

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).not_to have_key('password_default')
  end

  it 'la constante no existe más en el modelo' do
    expect(Club.const_defined?(:PASSWORD_DEFAULT)).to be(false)
  end
end
