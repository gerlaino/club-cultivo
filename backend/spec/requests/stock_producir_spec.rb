require 'rails_helper'

RSpec.describe 'POST /stocks/:id/producir (transformación)', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club) }
  let(:lote)  { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) }
  let(:stock) { create(:stock, club: club, sede: sede, lote: lote, cantidad: 100, costo_unitario_ars: 2) }

  before { sign_in_as(admin) }

  it 'consume flor del lote y crea un derivado con costo derivado' do
    stock   # fuerza la creación del stock origen antes de medir el count
    expect {
      post "/stocks/#{stock.id}/producir",
           params: { gramos_usados: 50, forma_producto: 'aceite', cantidad_producida: 10, unidad: 'ml', precio_sugerido_ars: 500 },
           headers: auth_headers, as: :json
    }.to change(Stock, :count).by(1)

    expect(response).to have_http_status(:created)
    body = JSON.parse(response.body)
    expect(body['forma_producto']).to eq('aceite')
    expect(stock.reload.cantidad.to_f).to eq(50.0)   # 100 − 50 consumidos

    nuevo = Stock.find(body['id'])
    expect(nuevo.origen).to eq('derivado_lote')
    expect(nuevo.cantidad.to_f).to eq(10.0)
    expect(nuevo.lote_origen_consumido_g.to_f).to eq(50.0)
    expect(nuevo.costo_unitario_ars.to_f).to eq(10.0)  # (2 × 50) / 10
    expect(nuevo.precio_sugerido_ars.to_f).to eq(500.0)
  end

  it 'rechaza si los gramos superan el stock' do
    post "/stocks/#{stock.id}/producir",
         params: { gramos_usados: 999, forma_producto: 'aceite', cantidad_producida: 10, unidad: 'ml' },
         headers: auth_headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'produce desde flor seca EXTERNA (sin lote) descontando del stock origen' do
    externo = create(:stock, :externo, club: club, sede: sede, forma_producto: 'flor_seca', cantidad: 200, costo_unitario_ars: 3)
    post "/stocks/#{externo.id}/producir",
         params: { gramos_usados: 80, forma_producto: 'prensado', cantidad_producida: 8, unidad: 'un' },
         headers: auth_headers, as: :json
    expect(response).to have_http_status(:created)
    expect(externo.reload.cantidad.to_f).to eq(120.0)   # 200 − 80
    nuevo = Stock.find(JSON.parse(response.body)['id'])
    expect(nuevo.origen).to eq('compra_externa')
    expect(nuevo.lote_id).to be_nil
    expect(nuevo.costo_unitario_ars.to_f).to eq(30.0)   # (3 × 80) / 8
  end

  it 'rechaza producto flor_seca' do
    post "/stocks/#{stock.id}/producir",
         params: { gramos_usados: 10, forma_producto: 'flor_seca', cantidad_producida: 10, unidad: 'g' },
         headers: auth_headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'el derivado hereda la genética, guarda observaciones y el link al origen' do
    genetica = create(:genetica, club: club, nombre: 'Lemon')
    origen   = create(:stock, :externo, club: club, sede: sede, forma_producto: 'flor_seca',
                       cantidad: 200, costo_unitario_ars: 3, genetica: genetica)
    post "/stocks/#{origen.id}/producir",
         params: { gramos_usados: 50, forma_producto: 'preroll', cantidad_producida: 25, unidad: 'un',
                   observaciones: 'lote de prueba' },
         headers: auth_headers, as: :json
    expect(response).to have_http_status(:created)

    nuevo = Stock.find(JSON.parse(response.body)['id'])
    expect(nuevo.genetica_id).to eq(genetica.id)               # heredó la genética
    expect(nuevo.descripcion).to eq('lote de prueba')          # observaciones
    expect(nuevo.producido_desde_stock_id).to eq(origen.id)    # link al origen
    expect(nuevo.unidad).to eq('un')
  end

  it 'borrar el derivado devuelve los gramos consumidos al stock origen' do
    origen = create(:stock, :externo, club: club, sede: sede, forma_producto: 'flor_seca', cantidad: 200, costo_unitario_ars: 3)
    post "/stocks/#{origen.id}/producir",
         params: { gramos_usados: 80, forma_producto: 'prensado', cantidad_producida: 8, unidad: 'un' },
         headers: auth_headers, as: :json
    derivado = Stock.find(JSON.parse(response.body)['id'])
    expect(origen.reload.cantidad.to_f).to eq(120.0)           # 200 − 80

    delete "/stocks/#{derivado.id}", headers: auth_headers, as: :json
    expect(response).to have_http_status(:no_content).or have_http_status(:ok)
    expect(origen.reload.cantidad.to_f).to eq(200.0)           # 80g devueltos
    expect(origen.stock_movimientos.where(tipo: 'ajuste').last.notas).to include('REVERSA PRODUCCIÓN')
  end
end
