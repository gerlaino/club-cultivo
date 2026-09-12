require 'rails_helper'

# Ningún informe decía cuánto se PERDIÓ. Producción cuenta lo que salió bien y trazabilidad
# cierra el balance de un producto, pero el club no tenía dónde ver lo que se cayó: plantas que
# no llegaron a cosecha y producto que salió del inventario sin entregarse. Cada cosa en su
# unidad, con lo que costó producirla, y por la fecha en que PASÓ (sep-2026).
RSpec.describe 'Informe de pérdidas', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala) }

  before { sign_in_as(admin) }

  def informe
    get '/api/informes/perdidas'
    expect(response).to have_http_status(:ok), response.body
    JSON.parse(response.body)
  end

  describe 'plantas descartadas' do
    before do
      create(:plant, lote: lote, club: club, state: 'descartada', motivo_descarte: 'plaga')
      create(:plant, lote: lote, club: club, state: 'descartada', motivo_descarte: 'plaga')
      create(:plant, lote: lote, club: club, state: 'descartada', motivo_descarte: 'macho')
      create(:plant, lote: lote, club: club, state: 'vegetativo')
    end

    it 'cuenta sólo las descartadas, y dice de cuántas en cultivo' do
      pl = informe['plantas']
      expect(pl['total']).to eq(3)
      expect(pl['en_cultivo']).to eq(1)
    end

    # El motivo es lo que hace accionable el informe: tres por plaga es un problema de sala;
    # tres machos es un problema de semilla. Y el LOTE: tres en el mismo lote es del lote.
    it 'las agrupa por motivo, con el lote' do
      m = informe['plantas']['por_motivo']
      expect(m.map { |x| [x['motivo'], x['plantas']] }).to eq([['plaga', 2], ['macho', 1]])
      expect(m.first['lotes']).to eq([{ 'codigo' => lote.codigo, 'plantas' => 2 }])
    end

    # Por la fecha en que PASÓ, nunca `updated_at`: corregirle el motivo a una planta descartada
    # en marzo la traía al mes de hoy.
    it 'una descartada hace meses no entra aunque se la haya editado hoy' do
      vieja = create(:plant, lote: lote, club: club, state: 'descartada', motivo_descarte: 'rotura')
      vieja.activities.create!(user: admin, activity_type: 'state_change', description: 'Descartada (estaba en vegetativo) — rotura', occurred_at: 5.months.ago)
      vieja.update!(motivo_descarte: 'otro')

      expect(informe['plantas']['total']).to eq(3)
    end

    it 'dice cuánto costó producirlas, prorrateando el costo del lote' do
      lote.update!(plants_count: 4)
      CostoLote.create!(lote: lote, club: club, costo_insumos: 4_000)

      expect(informe['plantas']['costo_ars']).to eq(3_000.0)
    end
  end

  describe 'producto perdido' do
    let(:stock)   { create(:stock, club: club, sede: sede, lote: lote, cantidad: 500, costo_unitario_ars: 100) }
    let(:preroll) { create(:stock, club: club, sede: sede, lote: lote, cantidad: 50, forma_producto: 'preroll', unidad: 'un') }

    it 'suma la merma declarada por unidad, con su nota y lo que costó' do
      stock.stock_movimientos.create!(tipo: 'merma', gramos: -50, usuario: admin, notas: 'se cayó el frasco')
      preroll.stock_movimientos.create!(tipo: 'merma', gramos: -4, usuario: admin)

      pr = informe['producto']
      expect(pr['merma_por_unidad']).to contain_exactly({ 'unidad' => 'g', 'cantidad' => 50.0 }, { 'unidad' => 'un', 'cantidad' => 4.0 })
      fila = pr['lista'].find { |f| f['frasco'] == stock.numero_lote_producto }
      expect(fila['detalle']).to eq('se cayó el frasco')
      expect(fila['costo_ars']).to eq(5_000.0)
      expect(pr['costo_ars']).to eq(5_000.0)
    end

    # Un ajuste en menos es producto que ya no está; uno en más no es pérdida.
    it 'suma los ajustes en menos, y NO los que suman' do
      stock.stock_movimientos.create!(tipo: 'ajuste', gramos: -20, usuario: admin)
      stock.stock_movimientos.create!(tipo: 'ajuste', gramos: 15, usuario: admin)

      expect(informe['producto']['por_unidad']).to eq([{ 'unidad' => 'g', 'cantidad' => 20.0, 'anterior' => nil }])
    end

    it 'una dispensación NO es una pérdida' do
      stock.stock_movimientos.create!(tipo: 'dispensacion', gramos: -30, usuario: admin)

      expect(informe['producto']['por_unidad']).to eq([])
    end
  end

  it 'dice de qué habla' do
    expect(informe['resena']).to match(/qué se perdió/i)
  end
end
