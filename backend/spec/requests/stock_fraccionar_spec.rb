require 'rails_helper'

# Fraccionar un stock a otra sede parte la fila en dos: baja la cantidad del origen y crea una
# fila nueva en el destino. El agujero era que la SALIDA no quedaba anotada en ninguna parte: el
# destino registraba su entrada, pero en el origen la cantidad bajaba sola. Quien miraba ese
# historial veía el número caer sin explicación, y el balance de trazabilidad no cerraba.
RSpec.describe 'POST /stocks/:id/asignar — fraccionar a otra sede', type: :request do
  let(:club)   { create(:club) }
  let(:admin)  { create(:user, :admin, club: club) }
  let(:origen) { create(:sede, club: club, created_by: admin) }
  let(:destino){ create(:sede, club: club, created_by: admin) }
  let(:sala)   { create(:sala, club: club, sede: origen, created_by: admin) }
  let(:lote)   { create(:lote, club: club, sala: sala) }
  let!(:stock) do
    Stock.create!(sede: origen, lote: lote, origen: 'lote', forma_producto: 'flor_seca',
                  unidad: 'g', cantidad: 100, estado: 'asignado', precio_sugerido_ars: 100)
  end

  before { sign_in_as(admin) }

  def fraccionar(cantidad)
    post "/stocks/#{stock.id}/asignar",
         params: { sede_id: destino.id, cantidad: cantidad }, headers: auth_headers, as: :json
  end

  it 'deja la salida anotada en el historial del stock de ORIGEN' do
    expect { fraccionar(30) }.to change { stock.stock_movimientos.count }.by(1)
    expect(response).to have_http_status(:ok)

    mov = stock.stock_movimientos.order(:id).last
    expect(mov.tipo).to eq('transferencia')
    expect(mov.gramos.to_f).to eq(-30.0)
    expect(mov.sede_destino_id).to eq(destino.id)
    expect(mov.usuario_id).to eq(admin.id)
  end

  it 'las dos puntas se nombran entre sí, para poder seguir el rastro desde cualquiera' do
    fraccionar(30)
    nuevo = Stock.where(club: club).order(:id).last

    salida  = stock.stock_movimientos.order(:id).last
    entrada = nuevo.stock_movimientos.order(:id).last
    expect(salida.notas).to  include(nuevo.numero_lote_producto)
    expect(entrada.notas).to include(stock.numero_lote_producto)
  end

  it 'el historial de cada punta cierra contra su cantidad' do
    fraccionar(30)
    nuevo = Stock.where(club: club).order(:id).last

    # Origen: arrancó en 100, salieron 30, quedan 70 y el libro lo dice.
    expect(stock.reload.cantidad.to_f).to eq(70.0)
    expect(stock.cantidad_inicial.to_f + stock.stock_movimientos.sum(:gramos).to_f).to eq(70.0)
    # Destino: nace con los 30 (su cantidad inicial ya los incluye).
    expect(nuevo.cantidad.to_f).to eq(30.0)
    expect(nuevo.cantidad_inicial.to_f).to eq(30.0)
  end

  it 'asignar el stock ENTERO no fracciona: no crea fila nueva ni mueve la cantidad' do
    expect { post "/stocks/#{stock.id}/asignar", params: { sede_id: destino.id },
                  headers: auth_headers, as: :json }.not_to change { Stock.where(club: club).count }
    expect(response).to have_http_status(:ok)
    expect(stock.reload.cantidad.to_f).to eq(100.0)
    expect(stock.sede_id).to eq(destino.id)
  end

  it 'no deja al origen en negativo ni pierde gramos por el camino' do
    fraccionar(30)
    nuevo = Stock.where(club: club).order(:id).last
    expect(stock.reload.cantidad.to_f + nuevo.cantidad.to_f).to eq(100.0)
  end
end
