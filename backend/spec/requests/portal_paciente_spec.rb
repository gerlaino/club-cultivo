require 'rails_helper'

# AC: lo que la organización le muestra a sus miembros es del MIEMBRO y de SU organización.
#
# Antes vivía bajo `Public::` y no pedía login: `Public::BaseController#current_club` era
# `Club.first` con un TODO, así que la web multi-club nunca funcionó y cualquiera que supiera la
# URL leía el catálogo de la organización número uno. Este spec fija las tres condiciones que
# antes no se cumplían: hace falta sesión, hace falta el módulo, y el club sale del usuario.
RSpec.describe 'Portal del paciente', type: :request do
  include AuthHelpers

  # Con todos los módulos: los roles que se prueban abajo necesitan el suyo para poder loguearse
  # (`check_rol_habilitado!`), y sin eso el spec daría 401 y parecería que el candado del portal
  # funciona cuando en realidad nunca llegó a evaluarse.
  let(:club) do
    create(:club, vista_paciente_activa: true,
                  features: { 'cultivo' => true, 'produccion_dispensa' => true, 'vista_paciente' => true })
  end
  let(:paciente) { create(:user, :paciente, club: club) }

  RUTAS = %w[club geneticas noticias eventos galeria].freeze

  def entrar(ruta) = get "/api/portal/#{ruta}"

  describe 'sin sesión' do
    it 'no entrega nada' do
      RUTAS.each do |ruta|
        entrar(ruta)
        expect(response).to have_http_status(:unauthorized), "#{ruta} contestó #{response.status} sin login"
      end
    end
  end

  describe 'con sesión de paciente y el módulo activo' do
    before { sign_in_as(paciente) }

    it 'entrega las cinco secciones' do
      RUTAS.each do |ruta|
        entrar(ruta)
        expect(response).to have_http_status(:ok), "#{ruta} contestó #{response.status}: #{response.body}"
      end
    end

    it 'el catálogo es el de SU organización y sólo lo publicado' do
      ActsAsTenant.with_tenant(club) do
        create(:genetica, club: club, nombre: 'Publicada', visible_paciente: true)
        create(:genetica, club: club, nombre: 'Guardada',  visible_paciente: false)
      end
      otro = create(:club, vista_paciente_activa: true, features: { 'vista_paciente' => true })
      ActsAsTenant.with_tenant(otro) { create(:genetica, club: otro, nombre: 'Ajena', visible_paciente: true) }

      entrar('geneticas')

      nombres = JSON.parse(response.body)['data'].map { |g| g['nombre'] }
      expect(nombres).to contain_exactly('Publicada')
    end

    it 'la ficha de la organización es la suya, no la primera de la base' do
      create(:club, name: 'La Primera') # existe antes en la tabla y NO tiene que salir
      entrar('club')

      expect(JSON.parse(response.body)['id']).to eq(club.id)
    end
  end

  # Sin el módulo el candado cae un escalón ANTES que en los demás roles: el paciente no tiene
  # otro lado donde ir, así que `check_rol_habilitado!` no lo deja ni loguearse. Es lo mismo que
  # le pasa al repartidor cuando la organización da de baja Delivery.
  describe 'sin el módulo contratado' do
    # El portal ABIERTO pero el add-on sin contratar: son dos llaves distintas y acá falta la del
    # super admin. Con las dos apagadas no se distinguiría cuál de las dos lo frenó.
    let(:club) { create(:club, vista_paciente_activa: true, features: { 'produccion_dispensa' => true }) }

    it 'el paciente no puede ni entrar, y se le dice qué falta' do
      post '/api/users/sign_in',
           params: { user: { email: paciente.email, password: 'password123' } }, as: :json

      expect(response).not_to have_http_status(:ok)
      expect(response.body).to include('Portal del paciente')
    end

    it 'y con la sesión de antes tampoco se llega al contenido' do
      club.update!(features: club.features.merge('vista_paciente' => true))
      sign_in_as(paciente)
      club.update!(features: club.features.merge('vista_paciente' => false))

      RUTAS.each do |ruta|
        entrar(ruta)
        expect(response).not_to have_http_status(:ok), "#{ruta} contestó 200 sin el módulo"
      end
    end
  end

  # No es una sección de operación, y tampoco una previsualización: es el área DEL paciente.
  # El admin que quiera ver cómo le queda se da de alta un paciente de prueba.
  describe 'con otro rol de la organización' do
    # El super admin no aparece acá: `block_super_admin_sin_contexto!` lo frena antes, con un 409
    # que explica qué le falta. Sumarlo a esta lista probaría ese guard, no éste.
    %i[dispensador admin cultivador medico].each do |rol|
      it "el #{rol} no entra" do
        sign_in_as(create(:user, rol, club: club))
        entrar('geneticas')

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end

# AC: el paciente ve SU historial y sólo el suyo. Es lo primero que va a buscar al entrar.
RSpec.describe 'Portal — el historial del paciente', type: :request do
  include AuthHelpers

  let(:club) do
    create(:club, vista_paciente_activa: true,
                  features: { 'produccion_dispensa' => true, 'vista_paciente' => true })
  end

  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala) }
  let(:stock) do
    Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca',
                  unidad: 'g', cantidad: 500, precio_sugerido_ars: 10)
  end

  def dispensar!(paciente)
    Dispensacion.create!(paciente: paciente, user: admin, stock: stock, sede: sede,
                         cantidad: 3, medio_pago: 'efectivo',
                         fecha_dispensacion: Time.zone.today, aporte_socio_ars: 30)
  end

  def con_cuenta(paciente)
    ActsAsTenant.with_tenant(club) do
      user = Pacientes::Acceso.crear!(paciente).user
      user.update!(password: AuthHelpers::DEFAULT_PASSWORD, password_confirmation: AuthHelpers::DEFAULT_PASSWORD)
      user
    end
  end

  it 'devuelve sólo sus dispensaciones, no las de otro paciente de la misma organización' do
    mias, ajenas, yo = ActsAsTenant.with_tenant(club) do
      yo   = create(:paciente, club: club, nombre: 'Yo',   apellido: 'Mismo',   created_by: admin)
      otro = create(:paciente, club: club, nombre: 'Otro', apellido: 'Distinto', created_by: admin)
      [dispensar!(yo), dispensar!(otro), yo]
    end

    sign_in_as(con_cuenta(yo))
    get '/api/portal/historial'

    expect(response).to have_http_status(:ok), response.body
    ids = JSON.parse(response.body)['data'].map { |d| d['id'] }
    expect(ids).to eq([mias.id])
    expect(ids).not_to include(ajenas.id)
  end

  # Los datos internos no salen por acá: el precio de costo, quién dispensó y las notas son de
  # la organización, no del paciente.
  it 'no expone el costo ni quién dispensó' do
    yo = ActsAsTenant.with_tenant(club) do
      paciente = create(:paciente, club: club, created_by: admin)
      dispensar!(paciente)
      paciente
    end

    sign_in_as(con_cuenta(yo))
    get '/api/portal/historial'

    fila = JSON.parse(response.body)['data'].first
    expect(fila.keys).to contain_exactly('id', 'fecha', 'token', 'gramos', 'total', 'items')
  end
end
