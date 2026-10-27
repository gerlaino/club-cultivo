require 'rails_helper'

# EL CHAT DEL PORTAL (27-oct-2026, Germán: «que desde el portal se le pueda mandar mensajes a la
# organización, y que el mensaje aparezca al admin dentro de la ficha de cada paciente, con la
# alerta correspondiente, armado tipo chat»).
#
# AC:
#   - El paciente escribe desde su portal; el mensaje aparece en la ficha de ESE paciente y en la
#     bandeja, primero los que esperan respuesta, con cuántos sin leer.
#   - Administración contesta y el paciente lo ve en su portal.
#   - Leer lo marca leído del otro lado (los tildes): abrir la conversación en la ficha la marca
#     leída para el paciente.
#   - «Resuelta» la cierra; un mensaje nuevo del paciente la reabre.
#   - Avisos en vivo (sin datos) a los dos lados, y push sin el texto.
#   - Nadie lee conversaciones ajenas: ni otro paciente, ni otra organización, ni un rol que no
#     atiende el chat. El paciente puede citar una dispensa SUYA, no la de otro.
RSpec.describe 'El chat del portal', type: :request do
  include AuthHelpers

  let(:club) do
    create(:club, name: 'Raíces', vista_paciente_activa: true,
                  features: { 'produccion_dispensa' => true, 'vista_paciente' => true })
  end
  let(:admin) { create(:user, :admin, club: club, first_name: 'Javier') }

  def paciente!(nombre = 'Lucía')
    create(:paciente, club: club, nombre: nombre, apellido: 'Fernández', created_by: admin, aprobado_at: Time.current)
  end

  def cuenta!(paciente)
    user = Pacientes::Acceso.crear!(paciente).user
    user.update!(password: AuthHelpers::DEFAULT_PASSWORD, password_confirmation: AuthHelpers::DEFAULT_PASSWORD)
    user
  end

  def escribir(texto, **extra) = post('/api/portal/mensajes', params: { texto: texto, **extra }, as: :json)
  def json = JSON.parse(response.body)

  describe 'el paciente escribe' do
    let(:lucia) { paciente! }

    it 'el mensaje queda en SU conversación y la organización lo ve en la ficha y en la bandeja' do
      sign_in_as(cuenta!(lucia))
      escribir('Hola! Ya subí la constancia del REPROCANN, ¿está bien?')
      expect(response).to have_http_status(:created), response.body

      sign_in_as(admin)
      get '/api/mensajes_pacientes'
      fila = json['data'].first
      expect(fila['paciente']['id']).to eq(lucia.id)
      expect(fila).to include('sin_leer' => 1, 'sin_responder' => true)
      expect(fila['ultimo']['texto']).to include('constancia')
      expect(json['sin_responder']).to eq(1)

      get "/api/pacientes/#{lucia.id}/mensajes"
      expect(json['data'].map { |m| [m['autor'], m['texto']] }).to eq([['paciente', 'Hola! Ya subí la constancia del REPROCANN, ¿está bien?']])
    end

    it 'el texto se guarda cifrado' do
      sign_in_as(cuenta!(lucia))
      escribir('Me cayó mal, me dio taquicardia')

      crudo = ActiveRecord::Base.connection.select_value('SELECT texto FROM mensajes_paciente LIMIT 1')
      expect(crudo).not_to include('taquicardia')
    end

    it 'avisa en vivo a la organización (sin datos) y al teléfono de administración sin el texto' do
      sign_in_as(cuenta!(lucia))
      expect(ActionCable.server).to receive(:broadcast).with("club_#{club.id}", hash_including(recurso: 'mensajes', accion: 'creado', id: lucia.id)).at_least(:once)
      allow(ActionCable.server).to receive(:broadcast).with(PacienteChannel.stream(lucia.id), anything)
      expect(PushNotificationService).to receive(:notify_roles_async)
        .with(anything, 'admin', 'supervisor', hash_including(tipo: 'mensaje_paciente', body: satisfy { |b| !b.include?('taquicardia') }))

      escribir('Me dio taquicardia')
    end

    it 'puede citar una dispensa suya, no la de otro paciente' do
      user = cuenta!(lucia)
      otro = paciente!('Martín')
      sede  = create(:sede, club: club, created_by: admin)
      stock = Stock.create!(sede: sede, origen: 'compra_externa', proveedor: 'X', forma_producto: 'flor_seca',
                            unidad: 'g', cantidad: 50, precio_sugerido_ars: 10)
      suya  = Dispensacion.create!(paciente: lucia, user: admin, stock: stock, sede: sede, cantidad: 1, medio_pago: 'efectivo',
                                   fecha_dispensacion: Time.zone.today, aporte_socio_ars: 10)
      ajena = Dispensacion.create!(paciente: otro, user: admin, stock: stock, sede: sede, cantidad: 1, medio_pago: 'efectivo',
                                   fecha_dispensacion: Time.zone.today, aporte_socio_ars: 10)
      sign_in_as(user)

      escribir('Una consulta por esta', dispensacion_id: suya.id)
      expect(response).to have_http_status(:created)
      expect(json['data']['dispensa']['id']).to eq(suya.id)

      escribir('Y por esta', dispensacion_id: ajena.id)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'un mensaje vacío no se manda' do
      sign_in_as(cuenta!(lucia))
      escribir('   ')
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'puede mandar una foto o un PDF, no cualquier archivo' do
      sign_in_as(cuenta!(lucia))
      pdf = Rack::Test::UploadedFile.new(StringIO.new('%PDF-1.4 constancia'), 'application/pdf', original_filename: 'constancia.pdf')
      post '/api/portal/mensajes', params: { adjunto: pdf }
      expect(response).to have_http_status(:created), response.body
      expect(json['data']['adjunto']).to include('nombre' => 'constancia.pdf', 'es_imagen' => false)

      exe = Rack::Test::UploadedFile.new(StringIO.new('MZ'), 'application/x-msdownload', original_filename: 'virus.exe')
      post '/api/portal/mensajes', params: { adjunto: exe }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'la organización contesta' do
    let(:lucia) { paciente! }
    let!(:user_lucia) { cuenta!(lucia) }

    before do
      sign_in_as(user_lucia)
      escribir('¿El jueves puedo pasar 19:30?')
    end

    it 'abrir la conversación la marca leída: el paciente lo ve en sus tildes' do
      sign_in_as(admin)
      get "/api/pacientes/#{lucia.id}/mensajes"

      sign_in_as(user_lucia)
      get '/api/portal/mensajes'
      mensaje = json['data'].first
      expect(Time.zone.parse(json['conversacion']['leida_org_at'])).to be >= Time.zone.parse(mensaje['at'])
    end

    it 'la respuesta le llega al paciente firmada con el nombre de quien contestó, y con push' do
      sign_in_as(admin)
      expect(PushNotificationService).to receive(:notify_user_async)
        .with(user_lucia, hash_including(tipo: 'respuesta_organizacion', title: 'Raíces te respondió'))
      post "/api/pacientes/#{lucia.id}/mensajes", params: { texto: 'Sí, te lo dejamos hasta las 20.' }, as: :json
      expect(response).to have_http_status(:created)

      sign_in_as(user_lucia)
      get '/api/portal/mensajes'
      expect(json['data'].last).to include('autor' => 'organizacion', 'quien' => 'Javier', 'texto' => 'Sí, te lo dejamos hasta las 20.')
      expect(json['sin_leer']).to eq(1)

      post '/api/portal/mensajes/leidos'
      get '/api/portal/mensajes'
      expect(json['sin_leer']).to eq(0)
    end

    it 'contestar deja de figurar como «sin responder»' do
      sign_in_as(admin)
      post "/api/pacientes/#{lucia.id}/mensajes", params: { texto: 'Sí.' }, as: :json

      get '/api/mensajes_pacientes', params: { filtro: 'sin_responder' }
      expect(json['data']).to be_empty
      expect(json['sin_responder']).to eq(0)
    end

    it '«Resuelta» la saca de las que esperan respuesta, y un mensaje nuevo del paciente la reabre' do
      sign_in_as(admin)
      post "/api/pacientes/#{lucia.id}/mensajes/resolver", as: :json
      get '/api/mensajes_pacientes'
      expect(json['sin_responder']).to eq(0)
      expect(json['data'].first['resuelta']).to be(true)

      sign_in_as(user_lucia)
      escribir('Otra cosa')
      sign_in_as(admin)
      get '/api/mensajes_pacientes'
      expect(json['data'].first).to include('resuelta' => false, 'sin_responder' => true)
    end
  end

  describe 'nadie lee lo ajeno' do
    it 'un paciente sólo ve SU conversación' do
      lucia  = paciente!
      martin = paciente!('Martín')
      sign_in_as(cuenta!(lucia))
      escribir('Lo mío')
      sign_in_as(cuenta!(martin))

      get '/api/portal/mensajes'

      expect(json['data']).to be_empty
    end

    it 'un paciente no entra a la bandeja de la organización' do
      sign_in_as(cuenta!(paciente!))
      get '/api/mensajes_pacientes'
      expect(response.status).to be_in([401, 403])
    end

    it 'el dispensador no atiende el chat' do
      lucia = paciente!
      sign_in_as(create(:user, :dispensador, club: club))
      get "/api/pacientes/#{lucia.id}/mensajes"
      expect(response).to have_http_status(:forbidden)
    end

    it 'el admin de otra organización no ve ni contesta a este paciente' do
      lucia = paciente!
      sign_in_as(cuenta!(lucia))
      escribir('Lo mío')
      otra = create(:club, vista_paciente_activa: true, features: { 'produccion_dispensa' => true, 'vista_paciente' => true })
      sign_in_as(create(:user, :admin, club: otra))

      get "/api/pacientes/#{lucia.id}/mensajes"
      expect(response).to have_http_status(:not_found)
      get '/api/mensajes_pacientes'
      expect(json['data']).to be_empty
    end

    it 'sin el portal contratado no hay chat' do
      club.update!(features: club.features.merge('vista_paciente' => false))
      sign_in_as(admin)
      get '/api/mensajes_pacientes'
      expect(response).to have_http_status(:forbidden)
    end
  end
end
