require 'rails_helper'

# Uso personal (sep-2026): el cultivador de casa. Es el plan `personal` y nada más —sin columna
# «tipo»—, y lo que lo distingue de una organización chica son tres cosas: sólo puede tener
# Cultivo (y lo que lo extiende), nadie más que él entra, y arranca con su casa ya creada.
RSpec.describe 'Uso personal', type: :request do
  def json = JSON.parse(response.body)

  describe 'el alta desde el super admin' do
    let(:super_admin) { create(:user, :super_admin) }
    before { sign_in_as(super_admin) }

    let(:alta) do
      {
        club: { name: 'Germán en casa', slug: "casa-#{SecureRandom.hex(3)}", plan: 'personal',
                # Por la API llega lo que sea: nada de esto puede quedar prendido.
                features: { 'produccion_dispensa' => true, 'delivery' => true, 'bar' => true, 'ia' => true } },
        roles_a_crear: %w[admin cultivador manicura],
        admin: { first_name: 'Germán', last_name: 'L', email: 'german@ejemplo.com' },
      }
    end

    it 'nace con Cultivo e IoT, y con lo que se pidió que sí puede tener' do
      post '/api/super_admin/clubs', params: alta, as: :json
      expect(response).to have_http_status(:created), response.body

      club = Club.find(json.dig('club', 'id'))
      expect(club).to be_personal
      expect(club.feature?('cultivo')).to be true
      expect(club.feature?('iot')).to be true
      expect(club.feature?('ia')).to be true
    end

    it 'no puede tener dispensa ni nada que cuelgue de ella' do
      post '/api/super_admin/clubs', params: alta, as: :json

      club = Club.find(json.dig('club', 'id'))
      %w[produccion_dispensa delivery bar medico mailer vista_paciente].each do |modulo|
        expect(club.feature?(modulo)).to be(false), "#{modulo} quedó prendido en un uso personal"
      end
    end

    it 'crea sólo al admin aunque el alta pida más roles' do
      post '/api/super_admin/clubs', params: alta, as: :json

      expect(json['usuarios'].map { |u| u['role'] }).to eq(%w[admin])
    end

    it 'arranca con su casa como única sede y sus depósitos sembrados' do
      post '/api/super_admin/clubs', params: alta, as: :json

      club = Club.find(json.dig('club', 'id'))
      ActsAsTenant.with_tenant(club) do
        expect(club.sedes.count).to eq(1)
        expect(club.sedes.first.nombre).to eq('Mi cultivo')
        expect(club.sedes.first.tipo).to eq('produccion')
        expect(club.depositos.count).to be_positive
      end
    end

    it 'una organización común sigue naciendo como siempre' do
      post '/api/super_admin/clubs', params: alta.merge(club: alta[:club].merge(plan: 'basico')), as: :json

      club = Club.find(json.dig('club', 'id'))
      expect(club).not_to be_personal
      expect(club.feature?('produccion_dispensa')).to be true
      ActsAsTenant.with_tenant(club) { expect(club.sedes.count).to eq(0) }
    end

    it 'editar los módulos tampoco deja meter dispensa' do
      post '/api/super_admin/clubs', params: alta, as: :json
      id = json.dig('club', 'id')

      patch "/api/super_admin/clubs/#{id}", params: { club: { features: { 'produccion_dispensa' => true } } }, as: :json

      expect(response).to have_http_status(:ok), response.body
      expect(Club.find(id).feature?('produccion_dispensa')).to be false
    end

    it 'pasar una organización con equipo a personal se rechaza con el motivo' do
      club = create(:club, plan: 'basico')
      create(:user, :cultivador, club: club)

      patch "/api/super_admin/clubs/#{club.id}/cambiar_plan", params: { plan: 'personal' }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['error']).to include('una sola persona')
      expect(club.reload).not_to be_personal
    end

    it 'pasar una organización sin equipo a personal apaga en el acto lo que no puede tener' do
      club = create(:club, plan: 'basico', features: { 'cultivo' => true, 'produccion_dispensa' => true, 'delivery' => true })

      patch "/api/super_admin/clubs/#{club.id}/cambiar_plan", params: { plan: 'personal' }

      expect(response).to have_http_status(:ok), response.body
      club.reload
      expect(club).to be_personal
      expect(club.feature?('cultivo')).to be true
      expect(club.feature?('produccion_dispensa')).to be false
      expect(club.feature?('delivery')).to be false
    end

    it 'el catálogo lo ofrece como plan sin equipo' do
      get '/api/super_admin/catalogo'

      personal = json['planes'].find { |p| p['clave'] == 'personal' }
      expect(personal).to include('equipo' => false, 'personal' => true)
      expect(json['modulos_personal']).to include('cultivo', 'iot')
    end
  end

  describe 'la cuenta es la persona' do
    let(:club)  { create(:club, plan: 'personal', features: { 'cultivo' => true, 'iot' => true }) }
    let(:admin) { create(:user, :admin, club: club) }
    before { sign_in_as(admin) }

    it 'no puede dar de alta a nadie, ni siquiera otro admin' do
      %w[admin cultivador].each do |rol|
        post '/api/usuarios', params: { user: { email: "#{rol}@casa.com", password: 'Clave1234!',
                                                first_name: 'Otro', last_name: 'X', role: rol } }

        expect(response).to have_http_status(:payment_required), "#{rol}: #{response.body}"
        expect(json['mensaje']).to include('una sola persona')
      end
      expect(club.users.count).to eq(1)
    end

    it 'no ofrece ningún rol para dar de alta' do
      expect(club.roles_para_alta).to eq([])
    end

    it 'tiene una sede y dos salas como mucho' do
      enforcer = PlanEnforcer.new(club)
      expect(enforcer.info[:limites]).to include(sedes: 1, salas: 2, lotes: nil, plantas: nil, pacientes: 0)
      expect(enforcer.info).to include(equipo: false, personal: true)
    end

    it 'la app se entera de que es personal' do
      get '/api/preferences'

      expect(json).to include('personal' => true, 'plan' => 'personal')
    end

    it 'la puesta en marcha no le pide sede ni equipo' do
      claves = Clubs::PuestaEnMarcha.de(club)[:pasos].map { |p| p[:clave] }
      expect(claves).to include('salas', 'lotes')
      expect(claves).not_to include('sedes', 'equipo', 'pacientes')
    end
  end

  describe 'lo que paga' do
    it 'es un solo número con Cultivo e IoT adentro, más la IA si la contrata' do
      club = create(:club, plan: 'personal', features: { 'cultivo' => true, 'iot' => true, 'ia' => true })
      lineas = Precios.de(club)[:lineas]

      expect(lineas.map { |l| l[:clave] }).to eq(%w[personal ia])
      expect(Precios.de(club)[:total]).to eq(Precios.plan('personal') + Precios.addon('ia'))
    end

    it 'tiene su propio tramo de IA' do
      club = create(:club, plan: 'personal')
      expect(club.ia_config[:label]).to eq('Personal')
    end
  end
end
