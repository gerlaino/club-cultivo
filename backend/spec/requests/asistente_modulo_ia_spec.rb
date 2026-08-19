require 'rails_helper'

# AC: si la organización tiene contratado el módulo de IA, el registro por voz funciona. La
# pantalla y el backend tienen que estar de acuerdo sobre eso.
#
# El bug que motiva el spec: `features` guarda la clave NUEVA (`ia`), pero cada acción del
# asistente chequeaba además la vieja (`ia_voz`). `feature?` resuelve viejo ⇒ nuevo, no al
# revés, así que devolvía false y el endpoint contestaba "no está disponible para este club" —
# mientras el botón se veía, porque `features_expandidas` (lo que lee la pantalla) sí lo
# derivaba. Prendido en el panel, prendido en el menú y rechazado al dictar.
#
# Las dos claves viejas siguen existiendo en organizaciones que las tienen guardadas, así que
# la equivalencia se prueba en los dos sentidos.
RSpec.describe 'Asistente: el módulo de IA', type: :request do
  include AuthHelpers

  let(:admin) { create(:user, :admin, club: club) }

  # `ejecutar` con la lista vacía no llama a la API de Anthropic: alcanza para probar el candado
  # del módulo sin gastar una llamada ni depender de la red.
  def dictar!
    # `as: :json` no es decorativo: form-encoded descarta el array vacío y el controller recibe
    # otra cosa.
    post '/api/asistente/ejecutar', params: { acciones: [] }, as: :json
  end

  def features_de_la_pantalla
    get '/api/preferences'
    JSON.parse(response.body)['features']
  end

  describe 'con la clave nueva guardada (`ia`)' do
    let(:club) { create(:club, features: { 'cultivo' => true, 'ia' => true }) }

    before { sign_in_as(admin) }

    it 'deja dictar' do
      dictar!

      expect(response).to have_http_status(:ok), response.body
    end

    it 'la pantalla lo ve prendido, igual que el backend' do
      expect(features_de_la_pantalla['ia']).to be(true)
    end
  end

  # Una organización vieja con `ia_voz` guardado tiene la capacidad `ia`: no hay que migrarla
  # para que le siga funcionando lo que ya usaba.
  describe 'con la clave vieja guardada (`ia_voz`)' do
    let(:club) { create(:club, features: { 'cultivo' => true, 'ia_voz' => true }) }

    before { sign_in_as(admin) }

    it 'deja dictar' do
      dictar!

      expect(response).to have_http_status(:ok), response.body
    end

    it 'la pantalla ve la capacidad nueva, no sólo la vieja' do
      expect(features_de_la_pantalla['ia']).to be(true)
    end
  end

  describe 'sin el módulo' do
    let(:club) { create(:club, features: { 'cultivo' => true }) }

    before { sign_in_as(admin) }

    it 'rechaza con 403 y dice qué módulo falta' do
      dictar!

      expect(response).to have_http_status(:forbidden)
      body = JSON.parse(response.body)
      expect(body['requiere_modulo']).to be(true)
      expect(body['modulo']).to eq('ia')
    end

    it 'y la pantalla tampoco lo ofrece' do
      expect(features_de_la_pantalla['ia']).not_to be(true)
    end
  end

  # El módulo prendido NO alcanza: además hay que tener un rol que use IA. El asistente no tenía
  # control de rol —sólo estar logueado y el feature— así que por API le podía pegar cualquiera
  # de la organización. La pantalla no se lo ofrece a nadie más, pero la regla viviendo sólo en
  # la pantalla está escondida, no aplicada.
  #
  # Con el tope en llamadas era un problema chico; contando créditos es un problema de plata: un
  # paciente curioso le come el cupo del mes a la organización.
  describe 'quién puede gastar crédito de IA' do
    # Una organización con TODO contratado, a propósito. Cada rol exige su propio módulo para
    # poder siquiera entrar (`User::MODULOS_POR_ROL`), así que con un club mínimo los roles
    # rechazados ni llegarían al asistente y el candado quedaría sin probar. Acá el dispensador,
    # el médico y el repartidor trabajan todos los días — y aun así no pueden dictar.
    let(:club) do
      create(:club, features: {
               'cultivo' => true, 'ia' => true, 'produccion_dispensa' => true,
               'bar' => true, 'medico' => true, 'delivery' => true, 'vista_paciente' => true
             })
    end

    %w[admin cultivador supervisor].each do |rol|
      it "el #{rol} puede dictar" do
        sign_in_as(create(:user, club: club, role: rol))
        dictar!

        expect(response).to have_http_status(:ok), response.body
      end
    end

    %w[dispensador medico paciente delivery abogado manicura].each do |rol|
      it "el #{rol} NO puede, aunque su rol esté habilitado y el módulo activo" do
        sign_in_as(create(:user, club: club, role: rol))
        dictar!

        expect(response).to have_http_status(:forbidden), "#{rol} pudo dictar: #{response.body}"
      end
    end
  end

  # El chatbot es un módulo APARTE de `ia`, no una función suya: una organización puede querer que
  # su equipo registre hablando sin abrirle a nadie una ventana que consulta la base entera.
  describe 'el chatbot del admin' do
    def preguntar!
      post '/api/asistente/chat', params: { texto: '¿qué genética rinde mejor?' }, as: :json
    end

    it 'con IA pero SIN el módulo chatbot, no contesta y dice cuál falta' do
      club = create(:club, features: { 'cultivo' => true, 'ia' => true })
      sign_in_as(create(:user, club: club, role: 'admin'))

      preguntar!

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['modulo']).to eq('chatbot')
    end

    it 'con el módulo activo, el cultivador tampoco entra: es del admin' do
      club = create(:club, features: { 'cultivo' => true, 'ia' => true, 'chatbot' => true })
      sign_in_as(create(:user, club: club, role: 'cultivador'))

      preguntar!

      expect(response).to have_http_status(:forbidden)
    end
  end

  # El Portal del paciente se pide por su clave nueva y por ninguna otra. `web_publica` era la
  # bandera de algo que nunca se vendió ni funcionó; ahora el portal se cobra, y dejar la
  # equivalencia sería una puerta de atrás por la que una organización se lo lleva gratis porque
  # alguien probó una bandera vieja.
  describe 'la bandera vieja de la web pública' do
    let(:club) { create(:club, features: { 'cultivo' => true, 'web_publica' => true }) }

    it 'no enciende el Portal del paciente' do
      expect(club.feature?('vista_paciente')).to be(false)
      expect(club.features_expandidas['vista_paciente']).not_to be(true)
    end
  end
end
