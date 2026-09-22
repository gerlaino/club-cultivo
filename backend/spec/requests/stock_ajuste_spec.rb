require 'rails_helper'

RSpec.describe 'POST /stocks/:id/ajuste (por cantidad real)', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club) }
  let(:lote)  { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) }
  let(:stock) { create(:stock, club: club, sede: sede, lote: lote, cantidad: 100) }

  before { sign_in_as(admin) }

  it 'calcula el delta desde la cantidad real ingresada' do
    post "/stocks/#{stock.id}/ajuste",
         params: { tipo: 'reconteo', cantidad_real: 92.5, motivo: 'reconteo físico' },
         headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(stock.reload.cantidad.to_f).to eq(92.5)
    mov = stock.stock_movimientos.where(tipo: 'ajuste').last
    expect(mov.gramos.to_f).to eq(-7.5)   # 92.5 - 100
  end

  it 'rechaza si la cantidad real es igual a la actual (delta 0)' do
    post "/stocks/#{stock.id}/ajuste",
         params: { tipo: 'reconteo', cantidad_real: 100, motivo: 'x' },
         headers: auth_headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  # UN AJUSTE NO CREA PRODUCTO (22-sep-2026, Germán). En un frasco que vino de una cosecha la
  # cantidad la justifica el pesaje: sumar gramos acá es cannabis de la nada. La puerta correcta
  # es corregir el pesaje, que arregla el peso confirmado Y el stock.
  it 'no deja SUMAR gramos a un stock que vino de la cosecha, y dice por dónde se corrige' do
    post "/stocks/#{stock.id}/ajuste",
         params: { tipo: 'reconteo', cantidad_real: 130, motivo: 'pesé de nuevo y había más' },
         headers: auth_headers, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)).to include('corregir_en' => 'pesaje', 'lote_id' => lote.id)
    expect(JSON.parse(response.body)['error']).to include('sale del pesaje')
    expect(stock.reload.cantidad.to_f).to eq(100.0)
  end

  it 'bajar sí se puede: se pierde producto, no se inventa' do
    post "/stocks/#{stock.id}/ajuste",
         params: { tipo: 'merma', cantidad_real: 80, motivo: 'se cayó un frasco' },
         headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok), response.body
    expect(stock.reload.cantidad.to_f).to eq(80.0)
  end

  # Lo comprado afuera sí sube: ahí el respaldo es la factura, no un pesaje.
  it 'un stock de compra externa sí puede subir' do
    externo = create(:stock, club: club, sede: sede, lote: nil, origen: 'compra_externa',
                             proveedor: 'Proveedor', cantidad: 100)
    post "/stocks/#{externo.id}/ajuste",
         params: { tipo: 'reconteo', cantidad_real: 130, motivo: 'faltaba cargar una compra' },
         headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok), response.body
    expect(externo.reload.cantidad.to_f).to eq(130.0)
  end

  # Una merma que suma es un contrasentido: si hay más, es un reconteo.
  it 'una merma o una pérdida no pueden sumar, ni siquiera en lo comprado' do
    externo = create(:stock, club: club, sede: sede, lote: nil, origen: 'compra_externa',
                             proveedor: 'Proveedor', cantidad: 100)
    post "/stocks/#{externo.id}/ajuste",
         params: { tipo: 'merma', cantidad_real: 130, motivo: 'x' },
         headers: auth_headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['error']).to include('elegí «reconteo»')
  end
end
