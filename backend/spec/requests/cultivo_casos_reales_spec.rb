require 'rails_helper'

# Fase 2 — Cultivo, desde la piel de quien lo usa. No verifica el camino feliz (eso ya está
# cubierto): fuerza las situaciones que pasan de verdad en un cuarto de cultivo y comprueba
# que la app responda con algo que se entienda y diga QUÉ HACER, no con un 500 ni con un
# error de validación crudo.
RSpec.describe 'Cultivo — casos reales', type: :request do
  let(:club)   { create(:club) }
  let(:admin)  { create(:user, :admin, club: club) }
  let(:sede)   { create(:sede, club: club, created_by: admin, tipo: 'produccion') }
  let(:otra_sede) { create(:sede, club: club, created_by: admin, tipo: 'produccion') }
  let(:vege)   { create(:sala, sede: sede, club: club, kind: 'vegetativo') }
  let(:flora)  { create(:sala, sede: sede, club: club, kind: 'floracion') }

  def json = JSON.parse(response.body)
  def error_msg = json['error'] || Array(json['errors']).join(', ')

  describe 'el cultivador recién creado, sin sedes asignadas' do
    let(:nuevo) { create(:user, :cultivador, club: club) }

    # DECISIÓN de diseño, no un descuido: sin sedes asignadas ve todo el cultivo del club.
    # Un club de una sola sede no debería tener que asignársela a cada persona para que la
    # app le sirva. La descripción del rol en la UI dice exactamente esto.
    it 'sin sedes asignadas ve el cultivo de todo el club' do
      create(:lote, club: club, sala: vege, estado: 'vegetativo')
      sign_in_as(nuevo)

      get '/api/lotes'

      expect(response).to have_http_status(:ok)
      expect(json.is_a?(Array) ? json : json['data']).not_to be_empty
    end
  end

  describe 'el cultivador de otra sede' do
    let(:cultivador) { create(:user, :cultivador, club: club) }

    before do
      cultivador.sedes_asignadas << otra_sede if cultivador.respond_to?(:sedes_asignadas)
      sign_in_as(cultivador)
    end

    it 'no puede tocar un lote que no es de su sede' do
      lote = create(:lote, club: club, sala: vege, estado: 'vegetativo')

      post "/api/lotes/#{lote.id}/avanzar_fase"

      # 404 y no 403: para él ese lote no existe. Un 403 confirmaría que existe.
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'avanzar de fase' do
    before { sign_in_as(admin) }

    # El caso más común del cuarto: el lote está listo para florar pero sigue en la sala de
    # vegetativo. El error tiene que decir qué hacer, no sólo que no se puede.
    it 'de vegetativo a floración sin mover de sala, avisa qué falta' do
      lote = create(:lote, club: club, sala: vege, estado: 'vegetativo', tamanio_maceta: 3)

      post "/api/lotes/#{lote.id}/avanzar_fase"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(error_msg).to match(/mov[eé]lo a una sala de floracion|mixta/i)
    end

    it 'de floración a cosecha pide los datos de la pesada, y lo dice' do
      lote = create(:lote, club: club, sala: flora, estado: 'floracion')

      post "/api/lotes/#{lote.id}/avanzar_fase"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(error_msg).to be_present
    end
  end

  describe 'registrar el ambiente de una sala' do
    before { sign_in_as(admin) }

    it 'una sala vacía lo dice en vez de fallar en silencio' do
      post "/api/salas/#{vege.id}/registrar_sala", params: { temperatura: 24, humedad: 60 }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(error_msg).to match(/no hay lotes activos/i)
    end

    # Un lote enraizando vive en su propio propagador: su ambiente entra por otra puerta.
    # Si sólo hay enraizando, el mensaje tiene que mandarte ahí y no decir "sala vacía".
    it 'con sólo lotes enraizando, manda a la puerta correcta' do
      create(:lote, club: club, sala: vege, estado: 'enraizado')

      post "/api/salas/#{vege.id}/registrar_sala", params: { temperatura: 24, humedad: 60 }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(error_msg).to match(/enraizando/i)
      expect(error_msg).to match(/registrar enraizado/i)
    end
  end

  describe 'dar vuelta la fase de una sala' do
    before { sign_in_as(admin) }

    it 'con esquejes adentro no se deja, y explica el riesgo' do
      create(:lote, club: club, sala: vege, estado: 'enraizado')

      post "/api/salas/#{vege.id}/cambiar_fase"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(error_msg).to match(/enraizando/i)
      expect(error_msg).to match(/no prenden|12\/12/i)
      expect(vege.reload.kind).to eq('vegetativo')
    end

    it 'una sala sin lotes de esa fase lo dice en vez de no hacer nada' do
      post "/api/salas/#{vege.id}/cambiar_fase"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(error_msg).to match(/no hay lotes/i)
    end
  end

  describe 'mover lotes entre salas' do
    before { sign_in_as(admin) }

    it 'a una sala que no existe, lo dice' do
      lote = create(:lote, club: club, sala: vege, estado: 'vegetativo')

      post '/api/lotes/mover', params: { lote_ids: [lote.id], sala_id: 999_999 }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(error_msg).to match(/sala destino/i)
    end

    it 'sin elegir ningún lote, lo dice' do
      post '/api/lotes/mover', params: { lote_ids: [], sala_id: vege.id }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(error_msg).to match(/eleg[íi] al menos un lote/i)
    end

    # Mover en tanda es donde más fácil se cuela un lote que no corresponde.
    it 'si uno de la tanda no puede entrar, nombra cuál y no mueve ninguno' do
      ok    = create(:lote, club: club, sala: vege, estado: 'vegetativo')
      malo  = create(:lote, club: club, sala: vege, estado: 'enraizado')

      post '/api/lotes/mover', params: { lote_ids: [ok.id, malo.id], sala_id: flora.id }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(error_msg).to include(malo.codigo)
      expect(ok.reload.sala_id).to eq(vege.id)
    end
  end

  describe 'el candado de manicura' do
    let(:manicura_a) { create(:user, :manicura, club: club) }
    let(:manicura_b) { create(:user, :manicura, club: club) }

    # Dos personas pesando el mismo lote se pisan los datos. El mensaje tiene que decir de
    # quién es el lote, no sólo "no autorizado".
    it 'otro manicura no registra el pesaje de un lote asignado, y se explica' do
      lote = create(:lote, club: club, sala: vege, estado: 'en_manicura', manicurador: manicura_a)
      sign_in_as(manicura_b)

      post "/api/lotes/#{lote.id}/pesajes_manicura", params: { peso_total_g: 100 }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(error_msg).to match(/asignado a otro responsable/i)
    end
  end

  describe 'un lote que ya no está' do
    before { sign_in_as(admin) }

    it 'devuelve 404 con mensaje, no un 500' do
      lote = create(:lote, club: club, sala: vege, estado: 'vegetativo')
      lote.soft_delete!

      get "/api/lotes/#{lote.id}"

      expect(response).to have_http_status(:not_found)
      expect(error_msg).to be_present
    end
  end
end
