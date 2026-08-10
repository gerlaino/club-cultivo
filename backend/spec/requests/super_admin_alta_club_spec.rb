require 'rails_helper'

# AC del alta de club (ago-2026): el plan y los módulos son decisiones separadas, se crean
# sólo los roles del arranque, y la contraseña temporal se puede ver.
RSpec.describe 'SuperAdmin alta de club', type: :request do
  let(:super_admin) { create(:user, :super_admin) }

  before { sign_in_as(super_admin) }

  def alta(club: {}, **extra)
    post '/api/super_admin/clubs',
         params: { club: { name: 'Club Nuevo', email: 'alta@club.test' }.merge(club) }.merge(extra),
         as: :json
    JSON.parse(response.body)
  end

  describe 'el plan' do
    it 'toma el plan elegido en el alta' do
      body = alta(club: { plan: 'total' })

      expect(response).to have_http_status(:created)
      expect(Club.find(body['club']['id']).plan).to eq('total')
    end

    it 'un plan viejo o desconocido se normaliza en vez de entrar crudo' do
      body = alta(club: { plan: 'federacion' })

      expect(Club.find(body['club']['id']).plan).to eq('total')
    end

    it 'sin plan explícito nace en el básico, no en el ilimitado' do
      body = alta

      expect(Club.find(body['club']['id']).plan).to eq('basico')
    end

    # El plan dice CUÁNTO: el alta lo informa junto con el uso, para que se vea contra qué mide.
    it 'devuelve los límites del plan en la ficha' do
      body = alta(club: { plan: 'basico' })

      expect(body['club']['plan_info']['limites']['salas']).to eq(3)
      expect(body['club']['plan_info']['uso']).to have_key('salas')
    end
  end

  describe 'los módulos' do
    it 'un club nuevo nace con las suites y el Buffet' do
      body = alta

      feats = Club.find(body['club']['id']).features
      expect(feats['cultivo']).to             be(true)
      expect(feats['produccion_dispensa']).to be(true)
      expect(feats['bar']).to                 be(true)
    end

    # Médico y correo no se guardan: se derivan de la suite que los incluye.
    it 'no guarda los módulos incluidos como banderas sueltas, pero el club los tiene' do
      body = alta
      club = Club.find(body['club']['id'])

      expect(club.features).not_to have_key('medico')
      expect(club.feature?(:medico)).to be(true)
      expect(club.feature?(:mailer)).to be(true)
    end

    it 'ignora un módulo en construcción aunque lo manden por la API' do
      body = alta(club: { features: { 'cultivo' => true, 'vista_paciente' => true } })
      club = Club.find(body['club']['id'])

      expect(club.features).not_to have_key('vista_paciente')
      expect(club.feature?(:vista_paciente)).to be(false)
    end

    it 'la ficha separa los tres cajones' do
      body = alta

      expect(body['club']['suites'].map  { |s| s['clave'] }).to include('cultivo')
      expect(body['club']['incluidos'].map { |i| i['clave'] }).to include('medico')
      expect(body['club']['en_construccion'].map { |e| e['clave'] }).to include('vista_paciente')
    end

    # Prendido no es lo mismo que andando: el panel tiene que poder decir la diferencia.
    it 'informa el estado real de cada módulo' do
      body = alta(club: { features: { 'cultivo' => true, 'produccion_dispensa' => true, 'whatsapp' => true } })

      whatsapp = body['club']['addons'].find { |a| a['clave'] == 'whatsapp' }
      expect(whatsapp['activo']).to be(true)
      expect(whatsapp['estado']).to eq('falta_config')
      expect(whatsapp['falta']).to  match(/Twilio/i)

      bar = body['club']['addons'].find { |a| a['clave'] == 'bar' }
      expect(bar['estado']).to eq('andando')
      expect(bar['falta']).to  be_nil
    end
  end

  describe 'los usuarios del arranque' do
    it 'crea sólo los roles pedidos' do
      body = alta(roles_a_crear: %w[admin cultivador])

      expect(body['usuarios'].map { |u| u['role'] }).to contain_exactly('admin', 'cultivador')
    end

    # No alcanza con sacarlos de la pantalla: el endpoint aceptaba lo que le mandaran.
    it 'descarta por la API los roles que el alta no ofrece' do
      body = alta(roles_a_crear: %w[admin supervisor auditor abogado])

      expect(body['usuarios'].map { |u| u['role'] }).to contain_exactly('admin')
    end

    it 'si no queda ningún rol válido crea al admin igual' do
      body = alta(roles_a_crear: %w[auditor])

      expect(body['usuarios'].map { |u| u['role'] }).to contain_exactly('admin')
    end

    # Es temporal y hay que poder dictársela: esconderla obligaba a acordarse de lo que uno
    # mismo acababa de tipear.
    it 'devuelve la contraseña temporal en claro' do
      body = alta(password_inicial: 'ClaveDelClub1')

      expect(body['password_inicial']).to eq('ClaveDelClub1')
      expect(User.find_by(email: body['usuarios'].first['email']).valid_password?('ClaveDelClub1')).to be(true)
    end

    it 'sin contraseña explícita devuelve la que usó por defecto' do
      body = alta

      expect(body['password_inicial']).to eq(Club::PASSWORD_DEFAULT)
    end
  end
end
