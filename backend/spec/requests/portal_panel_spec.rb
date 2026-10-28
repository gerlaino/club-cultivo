require 'rails_helper'

# «ARMÁ TU PORTAL» Y EL PANEL DEL PORTAL (Germán, 28-oct-2026: «tiene que ser mucho más fácil e
# intuitivo para alguien que no es de sistemas»).
#
# AC:
# - El admin ve si el portal está listo, paso por paso, deducido de lo que ya cargó: abierto,
#   presentación, algo para ver (genéticas o novedades), pacientes invitados.
# - Ve lo que espera respuesta: pedidos de Reservar sin confirmar, mensajes sin contestar y
#   renovaciones del REPROCANN subidas por el paciente; con el total y los primeros.
# - Ve a su padrón partido en: entran / invitados sin entrar / sin invitar / sin mail, y los ids de
#   los que puede invitar o recordarles por mail (sólo los que tienen mail).
# - Sólo el admin. Nada de otra organización.
# - Reservar y Mensajes se apagan por separado: apagados, el paciente no puede pedir ni escribir
#   (lo que ya tiene lo sigue viendo y puede cancelar su pedido), y el portal se lo dice.
RSpec.describe 'Portal — panel del admin y partes que se apagan', type: :request do
  include AuthHelpers

  let(:club)  { create(:club, vista_paciente_activa: true, features: { 'produccion_dispensa' => true, 'vista_paciente' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:supervisor) { create(:user, club: club, role: 'supervisor') }
  let(:sede)  { create(:sede, club: club, created_by: admin, nombre: 'Sede Centro', tipo: 'mixta') }

  def json = JSON.parse(response.body)

  def paciente!(email: 'p@example.com', en: club, **attrs)
    ActsAsTenant.with_tenant(en) { create(:paciente, club: en, aprobado_at: Time.current, email: email, **attrs) }
  end

  def activado!(paciente)
    ActsAsTenant.with_tenant(paciente.club) do
      Pacientes::Acceso.crear!(paciente)
      AccesoPortal.emitir!(paciente).acceso.usar!
    end
  end

  def invitado!(paciente)
    ActsAsTenant.with_tenant(paciente.club) do
      Pacientes::Acceso.crear!(paciente)
      AccesoPortal.emitir!(paciente)
    end
  end

  def panel(como: admin)
    sign_in_as(como)
    get '/api/portal_panel'
  end

  describe 'los pacientes' do
    it 'parte el padrón en entran / invitados sin entrar / sin invitar / sin mail' do
      activado!(paciente!)
      invitado!(paciente!)
      sin_invitar = paciente!
      sin_mail    = paciente!(email: nil)
      paciente!.update_column(:aprobado_at, nil) # pendiente de aprobar: no cuenta (el alta autoaprueba)
      paciente!(es_paciente: false)     # dado de baja: no cuenta

      panel
      expect(response).to have_http_status(:ok)
      expect(json['pacientes']).to include('total' => 4, 'entran' => 1, 'invitados_sin_entrar' => 1,
                                           'sin_invitar' => 2, 'sin_mail' => 1)
      expect(json['pacientes']['ids_invitar']).to eq([sin_invitar.id])
      expect(json['pacientes']['ids_invitar']).not_to include(sin_mail.id)
    end

    it 'a recordarles van sólo los invitados que no entraron y tienen mail' do
      invitado_con_mail = paciente!
      invitado!(invitado_con_mail)
      invitado!(paciente!(email: nil))

      panel
      expect(json['pacientes']['ids_recordar']).to eq([invitado_con_mail.id])
    end
  end

  describe 'los pasos de «Armá tu portal»' do
    it 'recién contratado: abierto y nada más' do
      panel
      expect(json['pasos']).to eq('abierto' => true, 'presentacion' => false, 'contenido' => false, 'invitados' => false)
    end

    it 'cada paso se tilda con lo que se cargó' do
      club.update!(horarios_atencion: 'Lun a vie 14 a 20')
      create(:genetica, club: club, visible_paciente: true)
      invitado!(paciente!)

      panel
      expect(json['pasos']).to eq('abierto' => true, 'presentacion' => true, 'contenido' => true, 'invitados' => true)
    end

    it 'cerrado: el primer paso no está hecho' do
      club.update!(vista_paciente_activa: false)
      panel
      expect(json['pasos']['abierto']).to be(false)
      expect(json['abierto']).to be(false)
    end
  end

  describe 'lo que espera respuesta' do
    it 'pedidos sin confirmar, mensajes sin contestar y renovaciones del portal, con el total' do
      p1 = paciente!(nombre: 'Lucía')
      cuenta = ActsAsTenant.with_tenant(club) do
        stock = Stock.create!(sede: sede, genetica: create(:genetica, club: club, nombre: 'Northern Lights', visible_paciente: true),
                              origen: 'compra_externa', proveedor: 'X', forma_producto: 'flor_seca', unidad: 'g', cantidad: 500,
                              precio_sugerido_ars: 1000)
        Mostradores::Cargar.call(mostrador: sede.mostrador!, usuario: admin, motivo: 'carga', cambios: [{ stock_id: stock.id, cantidad: 100 }])
        @stock = stock
        u = Pacientes::Acceso.crear!(p1).user
        u.update!(password: AuthHelpers::DEFAULT_PASSWORD, password_confirmation: AuthHelpers::DEFAULT_PASSWORD)
        u
      end
      sign_in_as(cuenta)
      post '/api/portal/reservas', params: { sede_id: sede.id, fecha: Time.zone.today.iso8601, items: [{ stock_id: @stock.id, cantidad: 10 }] }, as: :json
      expect(response).to have_http_status(:created), response.body
      post '/api/portal/mensajes', params: { texto: '¿Abren mañana?' }, as: :json

      panel
      atender = json['para_atender']
      expect(atender['pedidos']['total']).to eq(1)
      expect(atender['pedidos']['items'].first).to include('paciente_id' => p1.id, 'sede' => 'Sede Centro')
      expect(atender['pedidos']['items'].first['detalle']).to include('Northern Lights 10 g')
      expect(atender['mensajes']['total']).to eq(1)
      expect(atender['mensajes']['items'].first).to include('paciente_id' => p1.id)
      expect(atender['renovaciones']['total']).to eq(0)
    end

    it 'un mensaje ya contestado no espera nada' do
      p1 = paciente!
      ActsAsTenant.with_tenant(club) do
        conv = ConversacionPaciente.de!(p1)
        conv.mensajes.create!(club: club, autor: 'paciente', texto: 'Hola')
        conv.mensajes.create!(club: club, autor: 'organizacion', user: admin, texto: 'Hola, ¿cómo andás?')
      end

      panel
      expect(json['para_atender']['mensajes']['total']).to eq(0)
    end
  end

  describe 'quién lo ve' do
    it 'el supervisor no' do
      panel(como: supervisor)
      expect(response).to have_http_status(:forbidden)
    end

    it 'nada de otra organización: ni sus pacientes ni sus pedidos' do
      otra = create(:club, vista_paciente_activa: true, features: { 'vista_paciente' => true })
      activado!(paciente!(en: otra))
      paciente!(en: otra)

      panel
      expect(json['pacientes']).to include('total' => 0, 'entran' => 0)
      expect(json['para_atender']['pedidos']['total']).to eq(0)
    end
  end

  describe 'Reservar y Mensajes se apagan por separado' do
    let(:paciente) { paciente! }
    let(:cuenta) do
      ActsAsTenant.with_tenant(club) do
        u = Pacientes::Acceso.crear!(paciente).user
        u.update!(password: AuthHelpers::DEFAULT_PASSWORD, password_confirmation: AuthHelpers::DEFAULT_PASSWORD)
        u
      end
    end

    it 'el admin los apaga desde la configuración y el portal lo sabe' do
      sign_in_as(admin)
      put '/api/preferences', params: { club: { portal_reservar_activo: false, portal_mensajes_activo: false } }, as: :json
      expect(response).to have_http_status(:ok)
      expect(json).to include('portal_reservar_activo' => false, 'portal_mensajes_activo' => false)

      sign_in_as(cuenta)
      get '/api/portal/club'
      expect(json).to include('reservar' => false, 'mensajes' => false)
    end

    it 'con Reservar apagado no se puede pedir' do
      club.update!(portal_reservar_activo: false)
      sign_in_as(cuenta)
      post '/api/portal/reservas', params: { sede_id: sede.id, fecha: Time.zone.today.iso8601, items: [] }, as: :json
      expect(response).to have_http_status(:forbidden)
      expect(json['error']).to include('no toma reservas')
    end

    it 'con Reservar apagado sigue viendo los pedidos que ya hizo' do
      club.update!(portal_reservar_activo: false)
      sign_in_as(cuenta)
      get '/api/portal/reservas'
      expect(response).to have_http_status(:ok)
    end

    it 'con Mensajes apagado no se puede escribir, pero se lee lo que ya se habló' do
      club.update!(portal_mensajes_activo: false)
      sign_in_as(cuenta)
      post '/api/portal/mensajes', params: { texto: 'Hola' }, as: :json
      expect(response).to have_http_status(:forbidden)

      get '/api/portal/mensajes'
      expect(response).to have_http_status(:ok)
    end

    it 'con Mensajes prendido (lo de siempre) escribe' do
      sign_in_as(cuenta)
      post '/api/portal/mensajes', params: { texto: 'Hola' }, as: :json
      expect(response).to have_http_status(:created).or have_http_status(:ok)
    end

    it 'sólo el admin los cambia: el supervisor no' do
      sign_in_as(supervisor)
      put '/api/preferences', params: { club: { portal_reservar_activo: false } }, as: :json
      expect(response).to have_http_status(:forbidden)
      expect(club.reload.portal_reservar_activo).to be(true)
    end
  end
end
