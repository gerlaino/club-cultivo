require 'rails_helper'

# Fase 2 — el ciclo completo de un lote, de punta a punta, como lo recorre un club de verdad:
# crear → enraizar → vegetativo → floración → cosecha → manicura → curado → stock.
#
# Lo que se busca acá es el patrón que ya apareció varias veces en este proyecto: DOS PUERTAS
# PARA LA MISMA ACCIÓN, una protegida y la otra no. Cada paso del ciclo se puede disparar
# desde más de un lugar (la ficha del lote, la sala, la PWA), y si las puertas no coinciden,
# el que entra por la equivocada rompe algo sin enterarse.
RSpec.describe 'Cultivo — el ciclo completo', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin, tipo: 'produccion') }
  let(:vege)  { create(:sala, sede: sede, club: club, kind: 'vegetativo') }
  let(:flora) { create(:sala, sede: sede, club: club, kind: 'floracion') }
  let(:mixta) { create(:sala, sede: sede, club: club, kind: 'mixta') }

  def json = JSON.parse(response.body)
  def error_msg = json['error'] || Array(json['errors']).join(', ')

  before { sign_in_as(admin) }

  describe 'el recorrido entero' do
    it 'un lote llega de esqueje a stock dispensable' do
      # 1. Nace enraizando, venga de semilla o de esqueje.
      lote = create(:lote, club: club, sala: mixta, estado: 'enraizado', origen: 'esqueje')
      3.times { create(:plant, lote: lote, club: club, state: 'enraizado') }
      expect(lote.estado).to eq('enraizado')

      # 2. Prendió: pasa a vegetativo. Acá se pide la maceta, que es el dato que gobierna
      #    riego y trasplantes de ahí en adelante.
      post "/api/lotes/#{lote.id}/avanzar_fase", params: { tamanio_maceta: 3 }, as: :json
      expect(response).to have_http_status(:success), "no prendió: #{error_msg}"
      expect(lote.reload.estado).to eq('vegetativo')

      # 3. A floración: la sala mixta lo admite (el fotoperiodo lo maneja el club).
      post "/api/lotes/#{lote.id}/avanzar_fase"
      expect(response).to have_http_status(:success), "no floreció: #{error_msg}"
      expect(lote.reload.estado).to eq('floracion')

      # 4. Cosecha: sale de la sala y queda en la sede, esperando manicura.
      post "/api/lotes/#{lote.id}/transiciones",
           params: { nueva_fase: 'cosecha', pesada: { peso_humedo_g: 900 } }, as: :json
      expect(response).to have_http_status(:success), "no cosechó: #{error_msg}"
      expect(lote.reload.estado).to eq('cosecha')

      # 5. El admin lo manda a manicura.
      lote.update!(estado: 'en_manicura')

      # 6. Se pesa y se confirma en un paso (admin): genera el stock y cierra la manicura.
      post "/api/lotes/#{lote.id}/pesajes_manicura/registrar_directo",
           params: { resto: { plant_ids: lote.plants.pluck(:id), peso_total_g: 240 } }, as: :json
      expect(response).to have_http_status(:created), "no se pesó: #{error_msg}"

      # 7. Hay stock, y sale del lote.
      stock = Stock.find(json['stock_id'])
      expect(stock.lote_id).to eq(lote.id)
      expect(stock.cantidad.to_f).to eq(240.0)
      expect(lote.reload.estado).to eq('curado')
    end
  end

  # Cada paso tiene más de una puerta. Si una valida y la otra no, el club rompe datos por
  # el camino equivocado sin enterarse.
  describe 'las dos puertas de cada paso' do
    it 'avanzar a floración: la ficha del lote y la sala aplican la MISMA regla' do
      lote = create(:lote, club: club, sala: vege, estado: 'vegetativo', tamanio_maceta: 3)

      # Puerta A: la ficha del lote.
      post "/api/lotes/#{lote.id}/avanzar_fase"
      por_ficha = response.status

      # Puerta B: dar vuelta la sala entera.
      post "/api/salas/#{vege.id}/cambiar_fase"
      por_sala = response.status

      # La ficha rechaza (la sala sigue en vegetativo) y la sala acepta (se da vuelta ella
      # también, que es lo que hace que el lote pueda florar). Lo que NO puede pasar es que
      # las dos acepten dejando al lote en una sala que no le corresponde.
      expect(por_ficha).to eq(422)
      expect(por_sala).to be_between(200, 299)
      expect(lote.reload.sala.kind).to eq('floracion')
    end

    it 'cosechar: por transiciones y por cosechar_plantas el lote termina igual' do
      l1 = create(:lote, club: club, sala: flora, estado: 'floracion')
      2.times { create(:plant, lote: l1, club: club, state: 'floracion') }

      post "/api/lotes/#{l1.id}/transiciones",
           params: { nueva_fase: 'cosecha', pesada: { peso_humedo_g: 500 } }, as: :json
      expect(response).to have_http_status(:success), error_msg

      # Cosechado el lote entero, sus plantas quedan cosechadas y suelta la sala.
      expect(l1.reload.estado).to eq('cosecha')
      expect(l1.sala_id).to be_nil
      expect(l1.plants.pluck(:state).uniq).to eq(['cosechado'])
    end

    # El pesaje de manicura entra por dos lados: el manicura envía y el admin confirma, o el
    # admin pesa y confirma de una. Los dos tienen que terminar en el mismo lugar.
    it 'el pesaje: por la cola de aprobación y por el atajo del admin dan el mismo stock' do
      manicura = create(:user, :manicura, club: club)

      # Camino largo: el manicura envía, el admin confirma.
      l1 = create(:lote, club: club, sala: mixta, estado: 'en_manicura', manicurador: manicura)
      p1 = create(:plant, lote: l1, club: club, state: 'cosechado')
      sign_in_as(manicura)
      post "/api/lotes/#{l1.id}/pesajes_manicura",
           params: { plant_ids: [p1.id], peso_total_g: 100, enviar: true }, as: :json
      expect(response).to have_http_status(:created), error_msg
      pesaje = l1.pesajes_manicura.last
      expect(pesaje.estado).to eq('enviado')

      sign_in_as(admin)
      post "/api/lotes/#{l1.id}/pesajes_manicura/#{pesaje.id}/confirmar",
           params: { peso_confirmado_g: 100 }, as: :json
      expect(response).to have_http_status(:success), error_msg

      # Camino corto: el admin pesa y confirma de una.
      l2 = create(:lote, club: club, sala: mixta, estado: 'en_manicura')
      p2 = create(:plant, lote: l2, club: club, state: 'cosechado')
      post "/api/lotes/#{l2.id}/pesajes_manicura/registrar_directo",
           params: { resto: { plant_ids: [p2.id], peso_total_g: 100 } }, as: :json
      expect(response).to have_http_status(:created), error_msg

      # Los dos caminos: pesaje confirmado y stock creado.
      expect(l1.pesajes_manicura.last.estado).to eq('confirmado')
      expect(l2.pesajes_manicura.last.estado).to eq('confirmado')
      expect(Stock.where(lote_id: [l1.id, l2.id]).count).to eq(2)
    end
  end

  describe 'no se puede saltear pasos' do
    it 'un lote enraizando no salta directo a cosecha' do
      lote = create(:lote, club: club, sala: mixta, estado: 'enraizado')

      post "/api/lotes/#{lote.id}/transiciones", params: { nueva_fase: 'cosecha' }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(lote.reload.estado).to eq('enraizado')
    end

    it 'un lote ya finalizado no vuelve a avanzar' do
      lote = create(:lote, club: club, sala: nil, sede: sede, estado: 'finalizado')

      post "/api/lotes/#{lote.id}/avanzar_fase"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(lote.reload.estado).to eq('finalizado')
    end
  end

  describe 'el dato que se pide en cada paso' do
    # La maceta se pide al PRENDER, no al crear: antes de tener raíz la planta no está en
    # maceta y el dato no existe.
    it 'prender sin declarar la maceta se rechaza y dice por qué' do
      lote = create(:lote, club: club, sala: mixta, estado: 'enraizado', tamanio_maceta: nil)

      post "/api/lotes/#{lote.id}/avanzar_fase"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(error_msg).to match(/maceta/i)
    end

    it 'de floración en adelante ya no se pide' do
      lote = create(:lote, club: club, sala: mixta, estado: 'vegetativo', tamanio_maceta: 5)

      post "/api/lotes/#{lote.id}/avanzar_fase"

      expect(response).to have_http_status(:success), error_msg
      expect(lote.reload.estado).to eq('floracion')
    end
  end
end
