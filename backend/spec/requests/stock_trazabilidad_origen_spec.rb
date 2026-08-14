require 'rails_helper'

# AC (Germán): "la trazabilidad muestra 10 plantas del lote, pero de esas 10, 3 fueron descartadas
# por error humano —no porque murieron— y se registró el peso de tan sólo 2. Sin embargo aparecen
# todas. Registré el pesaje y creé dos recipientes, uno para cada planta: ¿no debería mostrar sólo
# eso? La trazabilidad de ese stock es UNA planta que perteneció a un lote."
#
# La causa: el stock de flor seca nace del flujo de manicura (`PesajeManicura`), pero la
# trazabilidad leía el vínculo por planta sólo del flujo viejo (`Pesada`). Como no encontraba
# nada, caía a "todas las plantas del lote", descartadas incluidas.
RSpec.describe 'GET /stocks/:id/trazabilidad — de qué plantas salió', type: :request do
  include AuthHelpers

  let(:club)        { create(:club) }
  let(:admin)       { create(:user, :admin, club: club) }
  let(:manicurador) { create(:user, club: club, role: 'manicura') }
  let(:sede)        { create(:sede, club: club, created_by: admin) }
  let(:sala)        { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)        { create(:lote, club: club, sala: sala, estado: 'en_manicura', manicurador: manicurador) }

  # El escenario de Germán: 10 plantas, 3 descartadas, se pesan 2 en su propio recipiente.
  let!(:pesadas)     { create_list(:plant, 2, lote: lote, club: club, state: 'cosechado') }
  let!(:sin_pesar)   { create_list(:plant, 5, lote: lote, club: club, state: 'cosechado') }
  let!(:descartadas) do
    create_list(:plant, 3, lote: lote, club: club, state: 'descartada', motivo_descarte: 'rotura')
  end

  def confirmar_pesaje_de(plantas, peso_c_u:)
    pesaje = lote.pesajes_manicura.create!(club: club, manicurador: manicurador, fecha_pesaje: Date.current)
    plantas.each { |pl| pesaje.pesadas_plantas.create!(plant: pl, peso_seco_g: peso_c_u) }
    pesaje.enviar!
    pesaje.confirmar!(confirmado_por: admin, peso_confirmado_g: peso_c_u * plantas.size)
    pesaje.reload.stock
  end

  def trazabilidad(stock)
    get "/stocks/#{stock.id}/trazabilidad", headers: auth_headers
    JSON.parse(response.body)
  end

  before { sign_in_as(admin) }

  context 'cuando el pesaje registró planta por planta' do
    it 'lista SOLO las plantas que se pesaron a ese recipiente' do
      stock = confirmar_pesaje_de(pesadas, peso_c_u: 50)

      ids = trazabilidad(stock)['plantas'].map { |p| p['id'] }
      expect(ids).to match_array(pesadas.map(&:id))
      expect(ids).not_to include(*sin_pesar.map(&:id))
      expect(ids).not_to include(*descartadas.map(&:id))
    end

    # El caso literal del reporte: un recipiente por planta.
    it 'un recipiente por planta traza a ESA planta y no al lote entero' do
      stock_a = confirmar_pesaje_de([pesadas.first], peso_c_u: 50)
      stock_b = confirmar_pesaje_de([pesadas.second], peso_c_u: 70)

      expect(trazabilidad(stock_a)['plantas'].map { |p| p['id'] }).to eq([pesadas.first.id])
      expect(trazabilidad(stock_b)['plantas'].map { |p| p['id'] }).to eq([pesadas.second.id])
    end

    it 'con el peso que aportó cada una' do
      stock = confirmar_pesaje_de(pesadas, peso_c_u: 50)

      expect(trazabilidad(stock)['plantas'].map { |p| p['peso_g'] }).to all(eq(50.0))
    end

    it 'y declara que la atribución es por planta' do
      stock = confirmar_pesaje_de(pesadas, peso_c_u: 50)

      expect(trazabilidad(stock)['atribucion']).to eq('planta')
    end
  end

  context 'cuando no hay pesaje planta por planta' do
    # Carga manual: el manicura declara peso total sin QR. Ahí lo único cierto es el lote.
    let(:stock_manual) do
      pesaje = lote.pesajes_manicura.create!(club: club, manicurador: manicurador,
                                             fecha_pesaje: Date.current, peso_total_g: 300,
                                             plantas_count: 7)
      pesaje.enviar!
      pesaje.confirmar!(confirmado_por: admin, peso_confirmado_g: 300)
      pesaje.reload.stock
    end

    it 'cae al lote, pero NO cuenta las descartadas como origen' do
      ids = trazabilidad(stock_manual)['plantas'].map { |p| p['id'] }

      expect(ids).to match_array((pesadas + sin_pesar).map(&:id))
      expect(ids).not_to include(*descartadas.map(&:id))
    end

    it 'y lo dice, para que no se lea como una medición por planta' do
      expect(trazabilidad(stock_manual)['atribucion']).to eq('lote')
    end
  end

  # Las descartadas no produjeron nada, pero sin ellas el hueco entre las plantas del lote y las
  # de origen no tiene explicación.
  describe 'las plantas descartadas' do
    it 'van aparte, con su motivo' do
      stock = confirmar_pesaje_de(pesadas, peso_c_u: 50)

      datos = trazabilidad(stock)
      expect(datos['plantas_descartadas'].size).to eq(3)
      expect(datos['plantas_descartadas'].map { |p| p['motivo_descarte'] }.uniq).to eq(['rotura'])
      expect(datos['totales']['plantas_descartadas']).to eq(3)
    end
  end
end
