require 'rails_helper'

# AC (25-ago): un adicional no existe suelto — extiende una suite. Y los usuarios que se crean
# tienen que servirle a lo que la organización contrató.
#
# Los dos agujeros que cierra: se podía prender Delivery sin Producción y dispensa (queda un
# módulo contratado que no hace nada, y el `requiere` lo decía en letra chica que nadie lee), y
# se podía dar de alta un cultivador en una organización sin Cultivo — esa persona loguea a una
# app sin una sola pantalla, y el que lo descubre es el cliente.
RSpec.describe 'SuperAdmin: módulos y roles coherentes', type: :request do
  let(:super_admin) { create(:user, :super_admin) }

  before { sign_in_as(super_admin) }

  def actualizar(club, features, **extra)
    patch "/api/super_admin/clubs/#{club.id}",
          params: { club: { features: features } }.merge(extra), as: :json
    JSON.parse(response.body)
  end

  describe 'un adicional sin su suite' do
    it 'no se puede prender' do
      club = create(:club, features: { 'cultivo' => true, 'produccion_dispensa' => false })

      actualizar(club, club.features.merge('delivery' => true))

      expect(club.reload.feature?('delivery')).to be(false)
    end

    it 'se puede prender en cuanto la suite entra' do
      club = create(:club, features: { 'cultivo' => true, 'produccion_dispensa' => false })

      actualizar(club, club.features.merge('produccion_dispensa' => true, 'delivery' => true))

      expect(club.reload.feature?('delivery')).to be(true)
    end

    it 'tampoco entra por el alta' do
      post '/api/super_admin/clubs',
           params: { club: { name: 'Sin suite', email: 'x@y.test',
                             features: { 'cultivo' => true, 'produccion_dispensa' => false,
                                         'delivery' => true } } },
           as: :json

      club = Club.find(JSON.parse(response.body)['club']['id'])
      expect(club.feature?('delivery')).to be(false)
    end

    # La baja de una suite NO corta hoy: sigue andando hasta el fin del período que la
    # organización ya pagó. Sus adicionales tienen que ir con ella — cortarlos hoy es cobrarle
    # el mes y no prestárselo.
    it 'la baja programada de la suite no corta sus adicionales' do
      club = create(:club, features: { 'cultivo' => true, 'produccion_dispensa' => true,
                                       'delivery' => true })

      actualizar(club, club.features.merge('produccion_dispensa' => false))

      expect(club.reload.feature?('delivery')).to be(true)
      expect(club.baja_programada?('produccion_dispensa')).to be(true)
    end
  end

  describe 'los usuarios que se crean en el alta' do
    it 'sólo los roles que le sirven a lo contratado' do
      post '/api/super_admin/clubs',
           params: { club: { name: 'Sólo dispensa', email: 'd@y.test',
                             features: { 'cultivo' => false, 'produccion_dispensa' => true } },
                     roles_a_crear: %w[admin cultivador dispensador] },
           as: :json

      roles = JSON.parse(response.body)['usuarios'].map { |u| u['role'] }
      expect(roles).to     include('admin', 'dispensador')
      expect(roles).not_to include('cultivador')
    end
  end

  describe 'el alta de un usuario suelto' do
    it 'rechaza un rol cuyo módulo la organización no tiene' do
      club = create(:club, features: { 'cultivo' => false, 'produccion_dispensa' => true })

      post '/api/super_admin/users',
           params: { user: { email: 'c@y.test', role: 'cultivador', club_id: club.id } }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['errors'].join).to include('Cultivo')
    end

    # El cupo del plan Básico es uno de cada rol. El mensaje tiene que nombrar el ROL: "permite
    # hasta 1 usuarios" no se entiende ni se puede accionar.
    it 'rechaza el segundo del mismo rol en el plan Básico y lo dice por su nombre' do
      club = create(:club, plan: 'basico')
      create(:user, club: club, role: 'cultivador')

      post '/api/super_admin/users',
           params: { user: { email: 'c2@y.test', role: 'cultivador', club_id: club.id } }, as: :json

      expect(response).to have_http_status(:payment_required)
      expect(JSON.parse(response.body)['mensaje']).to include('cultivador')
    end

    it 'el plan Total no limita ninguno' do
      club = create(:club, plan: 'total')
      create(:user, club: club, role: 'cultivador')

      post '/api/super_admin/users',
           params: { user: { email: 'c3@y.test', role: 'cultivador', club_id: club.id } }, as: :json

      expect(response).to have_http_status(:created)
    end

    # El admin no es un puesto de trabajo: es quien contrata, y son dos socios más veces de las
    # que es uno solo. Con tope de uno, el día que el único admin se va hay que meter mano en la
    # base para devolverle el control a alguien.
    it 'el admin queda fuera del cupo' do
      club = create(:club, plan: 'basico')
      create(:user, :admin, club: club)

      post '/api/super_admin/users',
           params: { user: { email: 'a2@y.test', role: 'admin', club_id: club.id } }, as: :json

      expect(response).to have_http_status(:created)
    end
  end

  describe 'créditos de IA vendidos aparte' do
    let(:club) { create(:club, plan: 'basico') }

    it 'le suben el tope de este mes y quedan registrados con quién los cargó' do
      post "/api/super_admin/clubs/#{club.id}/ia_recarga",
           params: { creditos: 300, nota: 'Campaña de agosto' }, as: :json

      expect(response).to have_http_status(:created)
      expect(club.reload.ia_limite_mes).to eq(Club::IA_TIERS['basico'][:limite_mes] + 300)

      recarga = ActsAsTenant.with_tenant(club) { IaRecarga.last }
      expect(recarga.creditos).to eq(300)
      expect(recarga.user_id).to  eq(super_admin.id)
      expect(recarga.mes).to      eq(Time.zone.today.beginning_of_month)
    end

    it 'no acepta una recarga vacía' do
      post "/api/super_admin/clubs/#{club.id}/ia_recarga", params: { creditos: 0 }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    # El tramo sale del plan: la perilla `ia_tier` era la misma decisión escrita en dos lugares
    # y podía quedar un club Total con la IA en Básico.
    it 'el tramo ya no se puede cambiar a mano' do
      patch "/api/super_admin/clubs/#{club.id}", params: { club: { ia_tier: 'enterprise' } }, as: :json

      expect(club.reload.ia_limite_mes).to eq(Club::IA_TIERS['basico'][:limite_mes])
    end
  end
end
