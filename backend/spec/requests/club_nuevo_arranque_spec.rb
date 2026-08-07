require 'rails_helper'

# Fase 4 — el primer día de un club. Sin datos previos es donde aparecen las pantallas vacías
# raras, los 500 por un nil y los mensajes que no dicen qué hacer. Es exactamente lo que va a
# vivir el club que arranca la semana que viene.
#
# El recorrido: club recién creado → sede → equipo → primer lote → primer paciente → primera
# dispensa. En cada paso, qué pasa si todavía no hay nada.
RSpec.describe 'Club nuevo — el primer día', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  def json = JSON.parse(response.body)
  def error_msg = json['error'] || Array(json['errors']).join(', ')

  describe 'el club sin nada cargado' do
    before { sign_in_as(admin) }

    # Ninguna pantalla puede explotar por estar vacía: es el estado en el que el club pasa
    # su primer día entero.
    it 'todas las pantallas principales abren sin romperse' do
      # `plants` (no `plantas`): la ruta de la API conserva el nombre legacy en inglés.
      %w[lotes salas plants geneticas pacientes dispensaciones stocks tareas
         sedes usuarios insumos].each do |recurso|
        get "/api/#{recurso}"

        expect(response.status).to be_between(200, 299),
          "GET /#{recurso} devolvió #{response.status}: #{response.body[0, 200]}"
      end
    end

    it 'los informes se abren aunque no haya un solo dato' do
      %w[reprocann produccion dispensaciones sedes cumplimiento plan_vs_real inase].each do |informe|
        get "/api/informes/#{informe}"

        expect(response).to have_http_status(:ok), "informe #{informe}: #{response.body[0, 200]}"
      end
    end

    it 'el dashboard contable no divide por cero' do
      get '/api/analytics/contabilidad'

      expect(response).to have_http_status(:ok)
    end

    it 'el informe semestral sale aunque el club no tenga pacientes' do
      get '/api/informe_semestral'

      expect(response).to have_http_status(:ok)
      expect(json.dig('pacientes', 'total')).to eq(0)
    end
  end

  describe 'el orden en que hay que hacer las cosas' do
    before { sign_in_as(admin) }

    # Sin sede no hay dónde poner una sala, ni a qué asignar a alguien. El error tiene que
    # decir por dónde empezar, no sólo que falta algo.
    it 'no se puede dar de alta gente operativa antes de crear una sede' do
      post '/api/usuarios', params: {
        user: { first_name: 'Ana', last_name: 'Gómez', email: 'ana@club.com', role: 'cultivador' }
      }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(error_msg).to match(/sede/i)
    end

    it 'pero el admin sí se puede crear: alguien tiene que configurar el club' do
      post '/api/usuarios', params: {
        user: { first_name: 'Otro', last_name: 'Admin', email: 'otro@club.com', role: 'admin' }
      }, as: :json

      expect(response).to have_http_status(:created)
    end

    it 'con la sede creada, ya se puede sumar al equipo' do
      create(:sede, club: club, created_by: admin, tipo: 'produccion')

      post '/api/usuarios', params: {
        user: { first_name: 'Ana', last_name: 'Gómez', email: 'ana@club.com', role: 'cultivador' }
      }, as: :json

      expect(response).to have_http_status(:created)
    end
  end

  describe 'el club arranca con lo mínimo para trabajar' do
    it 'nace con las dos suites y los add-ons terminados' do
      sign_in_as(create(:user, :super_admin))

      post '/api/super_admin/clubs', params: { club: { name: 'Club Nuevo', slug: 'club_nuevo' } }, as: :json

      expect(response).to have_http_status(:created)
      f = json.dig('club', 'features')
      expect(f['cultivo']).to be(true)
      expect(f['produccion_dispensa']).to be(true)
      # Los que no funcionan de verdad vienen apagados: prometer algo que no ocurre es peor
      # que no ofrecerlo.
      expect(f['ariccame']).to be_falsey
      expect(f['web_publica']).to be_falsey
    end

    # Las genéticas del INASE son GLOBALES (club_id: nil), no una copia por club: son
    # variedades registradas del país, iguales para todos, y un club nuevo las tiene desde el
    # primer minuto. (La factory de club las desactiva para no sembrar ocho registros en cada
    # spec, así que acá se verifica el método que las crea, no el estado de la base.)
    it 'y con las genéticas del INASE disponibles, para no arrancar de cero' do
      Genetica.where(global: true).delete_all
      Club.new(name: 'X', slug: 'x').crear_geneticas_default!

      expect(Genetica.where(global: true, registrada_inase: true).count).to be > 0
    end
  end

  describe 'el primer recorrido completo' do
    let!(:sede) { create(:sede, club: club, created_by: admin, tipo: 'mixta') }

    before { sign_in_as(admin) }

    it 'sede → sala → lote → paciente → dispensa, sin datos previos' do
      # 1. Sala
      post '/api/salas', params: { sala: { nombre: 'Sala 1', kind: 'mixta', sede_id: sede.id } }, as: :json
      expect(response).to have_http_status(:created), error_msg
      sala_id = json['id'] || json.dig('data', 'id')
      expect(sala_id).to be_present, "la sala se creó pero no vino el id: #{json.keys}"

      # 2. Lote, con una de las genéticas globales del INASE que ya están disponibles
      genetica = create(:genetica, club: club)
      # `sala_id` va a nivel raíz, no dentro de `lote`: el controller lo usa para resolver la
      # sala antes de armar el lote.
      post '/api/lotes', params: {
        sala_id: sala_id,
        lote: { genetica_id: genetica.id, estado: 'enraizado',
                start_date: Time.zone.today, plants_count: 5 }
      }, as: :json
      expect(response).to have_http_status(:created), error_msg

      # 3. Paciente
      post '/api/pacientes', params: {
        paciente: { nombre: 'Ana', apellido: 'Gómez', dni: '30111222',
                    fecha_nacimiento: 30.years.ago.to_date }
      }, as: :json
      expect(response).to have_http_status(:created), error_msg
      paciente_id = json.dig('data', 'id') || json['id']

      # 4. Un club que arranca todavía no cosechó: su primer stock es comprado.
      stock = create(:stock, club: club, sede: sede, origen: 'compra_externa',
                     proveedor: 'Cooperativa Norte', cantidad: 100, lote: nil,
                     precio_sugerido_ars: 1000)

      # 5. Primera dispensa
      post "/api/pacientes/#{paciente_id}/dispensaciones", params: {
        dispensacion: { stock_id: stock.id, cantidad: 10, fecha_dispensacion: Time.zone.today }
      }, as: :json
      expect(response).to have_http_status(:created), error_msg
      expect(stock.reload.cantidad.to_f).to eq(90.0)
    end
  end

  describe 'lo que el club ve mientras no configuró nada' do
    before { sign_in_as(admin) }

    # El onboarding se dispara por no tener sedes: si la app dijera que está todo bien, el
    # club se quedaría esperando.
    it 'no tiene sedes, que es lo que dispara la bienvenida' do
      get '/api/sedes'

      expect(response).to have_http_status(:ok)
      expect(json).to be_empty
    end

    it 'el módulo médico está disponible desde el día uno' do
      get '/api/medico/pacientes'

      expect(response).to have_http_status(:ok)
    end
  end
end
