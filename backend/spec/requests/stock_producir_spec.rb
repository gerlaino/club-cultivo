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

  it 'rechaza producto flor_seca' do
    post "/stocks/#{stock.id}/producir",
         params: { gramos_usados: 10, forma_producto: 'flor_seca', cantidad_producida: 10, unidad: 'g' },
         headers: auth_headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
