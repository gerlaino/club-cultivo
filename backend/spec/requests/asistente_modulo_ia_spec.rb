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

  # Lo que todavía no existe no se enciende por la puerta de atrás: `web_publica` es la clave
  # vieja de `vista_paciente`, que está EN CONSTRUCCIÓN.
  describe 'un módulo en construcción con la clave vieja guardada' do
    let(:club) { create(:club, features: { 'cultivo' => true, 'web_publica' => true }) }

    it 'sigue apagado' do
      expect(club.feature?('vista_paciente')).to be(false)
      expect(club.features_expandidas['vista_paciente']).not_to be(true)
    end
  end
end
