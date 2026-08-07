require 'rails_helper'

# AC: el admin da de alta a alguien y tiene que poder decirle CÓMO ENTRA. Y cuando esa
# persona olvide la contraseña, tiene que poder resolverlo sin depender de que el club
# tenga el correo configurado.
RSpec.describe 'Equipo — credenciales', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let!(:sede) { create(:sede, club: club, created_by: admin, tipo: 'produccion') }

  before { sign_in_as(admin) }

  def json = JSON.parse(response.body)

  def crear!(rol: 'cultivador', email: 'nuevo@club.com')
    post '/api/usuarios', params: {
      user: { first_name: 'Ana', last_name: 'Gómez', email: email, role: rol }
    }, as: :json
  end

  describe 'alta' do
    it 'devuelve las credenciales para poder dárselas a la persona' do
      crear!

      expect(response).to have_http_status(:created)
      expect(json['credenciales']['email']).to eq('nuevo@club.com')
      expect(json['credenciales']['password_inicial']).to be_present
    end

    # El frontend mandaba '123456Aa' para TODOS: cada usuario de cada club nacía con la
    # misma clave conocida.
    it 'cada usuario nace con una contraseña distinta' do
      crear!(email: 'uno@club.com')
      una = json['credenciales']['password_inicial']
      crear!(email: 'dos@club.com')
      otra = json['credenciales']['password_inicial']

      expect(una).not_to eq(otra)
    end

    it 'ignora la contraseña que mande el cliente' do
      post '/api/usuarios', params: {
        user: { first_name: 'B', last_name: 'C', email: 'x@club.com', role: 'cultivador',
                password: '123456Aa', password_confirmation: '123456Aa' }
      }, as: :json

      expect(json['credenciales']['password_inicial']).not_to eq('123456Aa')
      expect(User.find_by(email: 'x@club.com').valid_password?('123456Aa')).to be(false)
    end

    it 'la contraseña generada sirve para entrar' do
      crear!
      pass = json['credenciales']['password_inicial']

      expect(User.find_by(email: 'nuevo@club.com').valid_password?(pass)).to be(true)
    end

    # Sin SMTP el mail no sale, y el admin tiene que enterarse para dictarla él.
    it 'avisa si el mail no se pudo enviar' do
      crear!

      expect(json['credenciales']['mail_enviado']).to be(false)
    end
  end

  describe 'restablecer contraseña' do
    let(:otro) { create(:user, :cultivador, club: club) }

    it 'genera una nueva y la devuelve' do
      post "/api/usuarios/#{otro.id}/reset_password"

      expect(response).to have_http_status(:ok)
      expect(json['password_inicial']).to be_present
      expect(otro.reload.valid_password?(json['password_inicial'])).to be(true)
    end

    it 'la anterior deja de servir' do
      post "/api/usuarios/#{otro.id}/reset_password"

      expect(otro.reload.valid_password?('password123')).to be(false)
    end

    it 'sólo el admin puede' do
      sign_in_as(create(:user, :cultivador, club: club))

      post "/api/usuarios/#{otro.id}/reset_password"

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe User, '.password_temporal' do
    # Se dicta por teléfono: sin caracteres que se confundan al escucharla o al leerla.
    it 'no usa caracteres ambiguos' do
      20.times { expect(described_class.password_temporal).not_to match(/[0O1lI]/) }
    end

    it 'sirve como contraseña de Devise' do
      u = build(:user, club: club)
      pass = described_class.password_temporal
      u.password = u.password_confirmation = pass

      expect(u).to be_valid
    end
  end
end
