require 'rails_helper'

# AC: quien da de alta a alguien tiene que poder decirle CÓMO ENTRA. Y cuando esa persona olvide
# la contraseña, tiene que poder resolverlo sin depender de que el club tenga el correo
# configurado. Desde el 12-oct-2026 el alta la hace la plataforma (super admin); el restablecer
# sigue siendo del admin de la organización.
RSpec.describe 'Equipo — credenciales', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let!(:sede) { create(:sede, club: club, created_by: admin, tipo: 'produccion') }
  let(:super_admin) { create(:user, :super_admin, club: nil) }

  before { sign_in_as(admin) }

  def json = JSON.parse(response.body)

  # Lo que antes devolvía el alta del admin en `credenciales`, el alta de la plataforma lo devuelve
  # en la raíz (`email`, `password_inicial`, `mail_enviado`).
  def credenciales = json.slice('email', 'password_inicial', 'mail_enviado')

  def crear!(rol: 'cultivador', email: 'nuevo@club.com', extra: {})
    sign_in_as(super_admin)
    post '/api/super_admin/users', params: {
      user: { club_id: club.id, first_name: 'Ana', last_name: 'Gómez', email: email, role: rol }.merge(extra)
    }, as: :json
  end

  describe 'alta' do
    it 'devuelve las credenciales para poder dárselas a la persona' do
      crear!

      expect(response).to have_http_status(:created)
      expect(credenciales['email']).to eq('nuevo@club.com')
      expect(credenciales['password_inicial']).to be_present
    end

    # El frontend mandaba '123456Aa' para TODOS: cada usuario de cada club nacía con la
    # misma clave conocida.
    # Dos ROLES distintos a propósito: el plan Básico incluye uno de cada rol, así que dos
    # cultivadores rebotan por cupo antes de llegar a la contraseña, que es lo que se prueba acá.
    it 'cada usuario nace con una contraseña distinta' do
      crear!(email: 'uno@club.com', rol: 'cultivador')
      una = credenciales['password_inicial']
      crear!(email: 'dos@club.com', rol: 'dispensador')
      otra = credenciales['password_inicial']

      expect(una).not_to eq(otra)
    end

    it 'la contraseña generada sirve para entrar' do
      crear!
      pass = credenciales['password_inicial']

      expect(User.find_by(email: 'nuevo@club.com').valid_password?(pass)).to be(true)
    end

    # El link para elegir la clave sale por la casilla de la PLATAFORMA (no depende de que la
    # organización tenga correo) y sólo a una casilla real. Un login inventado (`rol@slug.com`)
    # sin mail personal no tiene a dónde ir, y el admin tiene que enterarse para dictarla él.
    it 'manda el link cuando el usuario tiene una casilla real' do
      expect { crear! }.to have_enqueued_mail(AccesoMailer, :restablecer_contrasena)

      expect(credenciales['mail_enviado']).to be(true)
    end

    it 'avisa que no salió cuando el login es inventado y no hay mail personal' do
      crear!(email: "nuevo@#{club.slug}.com")

      expect(credenciales['mail_enviado']).to be(false)
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
