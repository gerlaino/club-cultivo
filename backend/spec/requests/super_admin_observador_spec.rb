require 'rails_helper'

# AC del modo observador (ago-2026): el super admin "entra al club" y lo ve ENTERO como lo ve
# su admin, sin poder modificar absolutamente nada.
#
# La mitad de "no tocar nada" ya existía. La que faltaba era la de "ver": el super admin no
# tiene club propio, así que los ~370 puntos donde los controllers scopean por
# `current_user.club_id` le devolvían nil y no veía nada. El club efectivo se resuelve en
# User#club / #club_id mientras el modo está activo.
RSpec.describe 'Modo observador', type: :request do
  let(:super_admin) { create(:user, :super_admin) }

  let(:club_a) { create(:club, name: 'Club Observado') }
  let(:club_b) { create(:club, name: 'Club Ajeno') }

  def observar!(club)
    post "/api/super_admin/clubs/#{club.id}/observar"
  end

  # El modo está SUSPENDIDO (User::OBSERVADOR_HABILITADO = false): está a medias y entrar a
  # medias a un club que trabaja se nota. Estos specs describen el comportamiento que ya
  # funciona y vuelven solos el día que se reactive — no se borran, porque lo construido sigue
  # ahí y hay que poder verificar que no se pudrió mientras tanto.
  before do
    unless User::OBSERVADOR_HABILITADO
      skip 'modo observador suspendido — ver User::OBSERVADOR_HABILITADO'
    end
  end

  describe 'POST observar' do
    before { sign_in_as(super_admin) }

    it 'deja al super admin observando el club, en solo lectura y sin datos clínicos' do
      observar!(club_a)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['observando']).to         be(true)
      expect(body['club_id']).to            eq(club_a.id)
      expect(body['club_nombre']).to        eq('Club Observado')
      expect(body['solo_lectura']).to       be(true)
      expect(body['sin_acceso_clinico']).to be(true)
    end

    it 'la observación dura una hora' do
      observar!(club_a)

      expect(super_admin.reload.observer_expires_at).to be_within(1.minute).of(1.hour.from_now)
    end

    it 'un admin de club no puede observar a nadie' do
      sign_in_as(create(:user, :admin, club: club_a))

      observar!(club_b)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'el club efectivo' do
    it 'mientras observa, el club del usuario es el observado' do
      ActsAsTenant.with_tenant(club_a) do
        super_admin.update!(observer_club_id: club_a.id, observer_expires_at: 1.hour.from_now)

        expect(super_admin.club_id).to eq(club_a.id)
        expect(super_admin.club).to    eq(club_a)
      end
    end

    # El override es de LECTURA: el club real del super admin (ninguno) no se toca, y la
    # columna sigue siendo la que es. Si esto se rompiera, observar un club le cambiaría de
    # club al usuario de verdad.
    it 'no altera el club real ni lo que se persiste' do
      super_admin.update!(observer_club_id: club_a.id, observer_expires_at: 1.hour.from_now)

      expect(super_admin.club_id_original).to be_nil
      expect(super_admin.club_original).to    be_nil
      expect(User.where(club_id: club_a.id)).not_to include(super_admin)
    end

    it 'al vencer la observación vuelve a no tener club' do
      super_admin.update!(observer_club_id: club_a.id, observer_expires_at: 1.minute.ago)

      expect(super_admin.modo_observador?).to be(false)
      expect(super_admin.club_id).to          be_nil
    end

    it 'un usuario común no queda afectado' do
      admin = create(:user, :admin, club: club_a)

      expect(admin.modo_observador?).to be(false)
      expect(admin.club).to             eq(club_a)
    end
  end

  describe 'ver el club observado' do
    before do
      ActsAsTenant.with_tenant(club_a) { create(:sala, club: club_a, created_by: create(:user, :admin, club: club_a)) }
      sign_in_as(super_admin)
      observar!(club_a)
    end

    it 've los datos del club, que antes no veía' do
      get '/api/salas'

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(1)
    end

    it 'no ve los datos de otro club' do
      ActsAsTenant.with_tenant(club_b) { create(:sala, club: club_b, created_by: create(:user, :admin, club: club_b)) }

      get '/api/salas'

      nombres = JSON.parse(response.body).map { |s| s['club_id'] }.uniq
      expect(nombres).to eq([club_a.id])
    end
  end

  describe 'no puede modificar nada' do
    before do
      sign_in_as(super_admin)
      observar!(club_a)
    end

    it 'rechaza cualquier escritura' do
      post '/api/salas', params: { sala: { nombre: 'Sala del observador' } }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['error']).to match(/observación/i)
    end

    it 'rechaza los borrados' do
      delete '/api/salas/1'

      expect(response).to have_http_status(:forbidden)
    end

    # Sin esta excepción, el observador no podría ni salir del modo observador.
    it 'sí puede operar sobre el panel de plataforma' do
      delete "/api/super_admin/clubs/#{club_a.id}/detener_observacion"

      expect(response).to have_http_status(:no_content)
      expect(super_admin.reload.modo_observador?).to be(false)
    end
  end

  # Son datos de salud de terceros que nadie cedió para que los mire quien administra la
  # plataforma. Hace falta candado propio: los guards del namespace médico dejan pasar a
  # super_admin a propósito, para el soporte con la cuenta de plataforma.
  describe 'no accede a datos clínicos' do
    before do
      club_a.update!(features: { 'cultivo' => true, 'produccion_dispensa' => true })
      sign_in_as(super_admin)
      observar!(club_a)
    end

    it 'bloquea el namespace médico' do
      get '/api/medico/pacientes'

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['observador_sin_acceso_clinico']).to be(true)
    end

    it 'bloquea las indicaciones médicas' do
      get '/api/indicaciones_medicas'

      expect(response).to have_http_status(:forbidden)
    end

    it 'la ficha del paciente no trae la historia clínica' do
      paciente = ActsAsTenant.with_tenant(club_a) do
        create(:paciente, club: club_a, diagnostico_principal: 'SECRETO CLÍNICO')
      end

      get "/api/socios/#{paciente.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('SECRETO CLÍNICO')
    end

    # El candado es del MODO, no del rol ni de la ruta: al médico del propio club no lo toca.
    it 'no afecta a quien sí tiene que ver la historia clínica' do
      medico = create(:user, :medico, club: club_a)
      sign_in_as(medico)

      get '/api/medico/pacientes'

      expect(response).to have_http_status(:ok)
    end

    it 'deja de aplicar en cuanto se sale del modo observador' do
      delete "/api/super_admin/clubs/#{club_a.id}/detener_observacion"

      expect(super_admin.reload.modo_observador?).to be(false)
      # (El super admin sin observar no tiene club, así que los endpoints de club no le sirven
      # de nada: lo que importa acá es que el candado del observador ya no está puesto.)
    end
  end

  describe 'el gating por módulo del club observado' do
    before do
      sign_in_as(super_admin)
    end

    # Observar sirve para entender qué tiene delante el cliente: si el super admin viera
    # módulos que el club no compró, estaría mirando otra app.
    it 'no ve un módulo que el club no contrató' do
      club_a.update!(features: { 'cultivo' => true })
      observar!(club_a)

      get "/api/bares"

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['requiere_modulo']).to be(true)
    end

    # PENDIENTE — el observador pasa el gating por módulo, pero después lo frena el guard de
    # ROL del controller: `BaresController#require_operador` sólo admite admin/supervisor/
    # dispensador, y el observador sigue siendo `super_admin`.
    #
    # Es el límite conocido de este bloque: hay 26 controllers con allowlists de rol y 63
    # guards `require_*`, así que "ver todo como lo ve el admin" necesita que el observador
    # tenga ROL EFECTIVO de admin del club observado, no parchear guard por guard. Eso toca el
    # enum `User#role` (auth), y no se hace sin decisión explícita.
    it 've el módulo que el club sí contrató' do
      skip 'requiere rol efectivo de admin para el observador — pendiente de decisión'

      club_a.update!(features: { 'cultivo' => true, 'produccion_dispensa' => true, 'bar' => true })
      observar!(club_a)

      get '/api/bares'

      expect(response).to have_http_status(:ok)
    end

    # El gating normal del club no cambia: un admin con el módulo prendido sigue entrando.
    it 'no cambia el gating de los usuarios del club' do
      club_a.update!(features: { 'cultivo' => true, 'produccion_dispensa' => true, 'bar' => true })
      sign_in_as(create(:user, :admin, club: club_a))

      get '/api/bares'

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /me' do
    it 'informa que está observando, con qué club y hasta cuándo' do
      sign_in_as(super_admin)
      observar!(club_a)

      get '/api/me'

      obs = JSON.parse(response.body)['observando']
      expect(obs['club_id']).to            eq(club_a.id)
      expect(obs['club_nombre']).to        eq('Club Observado')
      expect(obs['solo_lectura']).to       be(true)
      expect(obs['sin_acceso_clinico']).to be(true)
      expect(obs['expires_at']).to         be_present
    end

    it 'sin observación no informa nada' do
      sign_in_as(super_admin)

      get '/api/me'

      expect(JSON.parse(response.body)).not_to have_key('observando')
    end
  end
end
