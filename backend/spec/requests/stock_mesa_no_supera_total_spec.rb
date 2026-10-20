require 'rails_helper'

# AC (20-oct-2026, Germán, en prod con ST-26-0028): «había 132, hice una verificación de stock y en
# realidad hay 70; ajusté como reconteo a 70 y sobre la mesa siguen quedando 132».
#
# Depósito + mesa = lo que hay. Si el total baja por debajo de lo que la mesa tiene arriba, lo que
# falta salió de la mesa (en el depósito no había) y la mesa baja con su movimiento. Si el total
# sigue cubriendo la mesa, lo que falta sale del depósito y la mesa no se toca.
RSpec.describe 'La mesa nunca tiene más que el frasco', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'social') }
  let(:stock) do
    create(:stock, club: club, sede: sede, lote: nil, origen: 'compra_externa', proveedor: 'Proveedor', cantidad: 132)
  end

  before { sign_in_as(admin) }

  def poner_en_mesa(st, gramos, en: sede)
    ActsAsTenant.with_tenant(club) { MostradorItem.create!(club: club, mostrador: en.mostrador!, stock: st, cantidad: gramos) }
  end

  def en_mesa(st) = ActsAsTenant.with_tenant(club) { MostradorItem.where(stock: st).sum(:cantidad).to_f }

  def ajustar(st, a, tipo: 'reconteo')
    post "/stocks/#{st.id}/ajuste", params: { tipo: tipo, cantidad_real: a, motivo: 'verificación de stock' },
                                    headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok), response.body
  end

  it 'el caso de la captura: todo sobre la mesa, reconteo a 70 → la mesa queda en 70, con su movimiento' do
    item = poner_en_mesa(stock, 132)

    ajustar(stock, 70)

    expect(stock.reload.cantidad.to_f).to eq(70.0)
    expect(en_mesa(stock)).to eq(70.0)
    mov = ActsAsTenant.with_tenant(club) { item.movimientos.order(:id).last }
    expect(mov.tipo).to eq('ajuste')
    expect(mov.cantidad.to_f).to eq(-62.0)
    expect(mov.usuario).to eq(admin)
    expect(mov.motivo).to include('verificación de stock')
  end

  it 'si el depósito alcanza para lo que falta, la mesa no se toca' do
    poner_en_mesa(stock, 50)   # 82 en el depósito

    ajustar(stock, 70)          # faltan 62: salen del depósito

    expect(en_mesa(stock)).to eq(50.0)
  end

  it 'si falta más que lo del depósito, la mesa baja sólo lo que no alcanzó' do
    poner_en_mesa(stock, 100)  # 32 en el depósito

    ajustar(stock, 70)          # faltan 62: 32 del depósito, 30 de la mesa

    expect(en_mesa(stock)).to eq(70.0)
  end

  it 'con dos mesas, se recorta sólo el sobrante entre las dos' do
    otra = create(:sede, club: club, tipo: 'social')
    poner_en_mesa(stock, 80)
    poner_en_mesa(stock, 52, en: otra)

    ajustar(stock, 70, tipo: 'merma')

    expect(en_mesa(stock)).to eq(70.0)
  end

  it 'finalizar el stock vacía la mesa' do
    poner_en_mesa(stock, 40)

    post "/stocks/#{stock.id}/descartar", params: { motivo: Stock::MOTIVOS_FINALIZACION.keys.first },
                                          headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok), response.body

    expect(en_mesa(stock)).to eq(0.0)
  end

  it 'editar la cantidad de un externo por debajo de la mesa también la recorta' do
    poner_en_mesa(stock, 132)

    put "/stocks/#{stock.id}", params: { stock: { cantidad: 100 } }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok), response.body

    expect(en_mesa(stock)).to eq(100.0)
  end

  it 'producir un derivado con la flor que estaba sobre la mesa la baja' do
    poner_en_mesa(stock, 132)
    ActsAsTenant.with_tenant(club) { stock.update_columns(forma_producto: 'flor_seca', disponibilidad: 'ambas') }

    post "/stocks/#{stock.id}/producir",
         params: { gramos_usados: 32, forma_producto: 'aceite', cantidad_producida: 10, unidad: 'ml' },
         headers: auth_headers, as: :json
    expect(response).to have_http_status(:created).or have_http_status(:ok)

    expect(en_mesa(stock)).to eq(100.0)
  end
end
