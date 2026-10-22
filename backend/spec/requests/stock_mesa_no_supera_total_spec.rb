require 'rails_helper'

# AC (22-oct-2026, Germán, sobre los 22 stocks de Mitocondria con más en la mesa que en el frasco):
# «contó lo que había de stock, hizo el reconteo pero nunca se reflejó bien el total».
#
# El total es depósito + mesa. Quien recuenta pesa lo que ve en cada lugar y el total lo calcula la
# máquina: un reconteo nunca puede volver a cargar como total lo que hay sólo en el depósito, ni
# borrar en silencio lo que está sobre la mesa. Un frasco de cosecha recupera lo que un reconteo
# anterior le sacó, y nada más.
#
# (Reemplaza el AC del 20-oct, «un reconteo a la baja también baja la mesa»: con el reconteo del
# depósito eso borraba producto real.)
RSpec.describe 'Recontar: depósito y mesa por separado', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'mixta', nombre: 'Centro') }
  let(:externo) do
    create(:stock, :externo, club: club, sede: sede, cantidad: 132)
  end
  let(:lote) { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }
  let(:cosecha) { ActsAsTenant.with_tenant(club) { create(:stock, club: club, sede: sede, lote: lote, cantidad: 168) } }

  before { sign_in_as(admin) }

  def poner_en_mesa(st, gramos, en: sede)
    ActsAsTenant.with_tenant(club) { MostradorItem.create!(club: club, mostrador: en.mostrador!, stock: st, cantidad: gramos) }
  end

  def en_mesa(st) = ActsAsTenant.with_tenant(club) { MostradorItem.where(stock: st).sum(:cantidad).to_f }

  def recontar(st, deposito:, mesas:)
    post "/stocks/#{st.id}/ajuste", params: { tipo: 'reconteo', deposito: deposito, mesas: mesas, motivo: 'pesé todo' },
                                    headers: auth_headers, as: :json
  end

  # Así quedaron en prod: un reconteo que pesó el depósito (53) y lo cargó como total.
  def reconteo_viejo_del_deposito!(st, mesa:, deposito:)
    ActsAsTenant.with_tenant(club) do
      st.update!(cantidad: deposito)
      st.stock_movimientos.create!(tipo: 'ajuste', gramos: -mesa, usuario: admin, notas: '[RECONTEO] pesé el frasco')
    end
  end

  describe 'el caso de prod: total 53, mesa 115 (un reconteo cargó el depósito como total)' do
    let!(:item) { poner_en_mesa(cosecha, 115) }
    before { reconteo_viejo_del_deposito!(cosecha, mesa: 115, deposito: 53) }

    it 'si la mesa es real: depósito 53 + mesa 115 → el total vuelve a 168 y la mesa no se toca' do
      recontar(cosecha, deposito: 53, mesas: { item.id => 115 })
      expect(response).to have_http_status(:ok), response.body

      expect(cosecha.reload.cantidad.to_f).to eq(168.0)
      expect(en_mesa(cosecha)).to eq(115.0)
      mov = ActsAsTenant.with_tenant(club) { cosecha.stock_movimientos.order(:id).last }
      expect(mov.gramos.to_f).to eq(115.0)
      expect(mov.notas).to include('[RECONTEO]', 'depósito 53', 'mesa 115')
    end

    it 'si la mesa estaba inflada: depósito 0 + mesa 53 → el total queda en 53 y la mesa baja a 53, con su movimiento' do
      recontar(cosecha, deposito: 0, mesas: { item.id => 53 })
      expect(response).to have_http_status(:ok), response.body

      expect(cosecha.reload.cantidad.to_f).to eq(53.0)
      expect(en_mesa(cosecha)).to eq(53.0)
      mov = ActsAsTenant.with_tenant(club) { item.movimientos.order(:id).last }
      expect([mov.tipo, mov.cantidad.to_f, mov.usuario]).to eq(['ajuste', -62.0, admin])
      expect(mov.motivo).to include('pesé todo')
    end

    it 'el total contado «de una» (el error de siempre) se rechaza y no cambia nada' do
      post "/stocks/#{cosecha.id}/ajuste", params: { tipo: 'reconteo', cantidad_real: 53, motivo: 'x' },
                                           headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to include('sobre la mesa')
      expect([cosecha.reload.cantidad.to_f, en_mesa(cosecha)]).to eq([53.0, 115.0])
    end
  end

  it 'un frasco de cosecha no gana más de lo que le sacaron los reconteos' do
    item = poner_en_mesa(cosecha, 115)
    reconteo_viejo_del_deposito!(cosecha, mesa: 62, deposito: 106) # sólo 62 salieron por reconteo

    recontar(cosecha, deposito: 53, mesas: { item.id => 115 })     # pediría +62... y 168−106 = +62: entra justo
    expect(response).to have_http_status(:ok), response.body

    recontar(cosecha, deposito: 60, mesas: { item.id => 115 })     # +7 más: ya no hay nada que devolver
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to include('pesaje')
    expect(cosecha.reload.cantidad.to_f).to eq(168.0)
  end

  it 'un frasco de cosecha sin reconteos previos no sube por un reconteo' do
    item = poner_en_mesa(cosecha, 100)
    recontar(cosecha, deposito: 80, mesas: { item.id => 100 })     # 180 > 168
    expect(response).to have_http_status(:unprocessable_entity)
    expect(cosecha.reload.cantidad.to_f).to eq(168.0)
  end

  it 'contar menos en el depósito baja el total y deja la mesa como estaba' do
    item = poner_en_mesa(externo, 100) # 32 en el depósito

    recontar(externo, deposito: 20, mesas: { item.id => 100 })
    expect(response).to have_http_status(:ok), response.body

    expect(externo.reload.cantidad.to_f).to eq(120.0)
    expect(en_mesa(externo)).to eq(100.0)
  end

  it 'si coincide con lo que había, no deja movimientos y lo dice' do
    item = poner_en_mesa(externo, 100)
    expect {
      recontar(externo, deposito: 32, mesas: { item.id => 100 })
    }.not_to(change { ActsAsTenant.with_tenant(club) { [StockMovimiento.count, MostradorMovimiento.count] } })
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['sin_cambios']).to be(true)
  end

  it 'con dos mesas hay que contar las dos; faltando una, no cambia nada' do
    otra = create(:sede, club: club, tipo: 'social')
    a = poner_en_mesa(externo, 80)
    b = poner_en_mesa(externo, 30, en: otra)

    recontar(externo, deposito: 22, mesas: { a.id => 80 })
    expect(response).to have_http_status(:unprocessable_entity)
    expect(externo.reload.cantidad.to_f).to eq(132.0)

    recontar(externo, deposito: 22, mesas: { a.id => 80, b.id => 25 })
    expect(response).to have_http_status(:ok), response.body
    expect([externo.reload.cantidad.to_f, en_mesa(externo)]).to eq([127.0, 105.0])
  end

  it 'el stock ofrece a la pantalla cada mesa y lo que puede volver' do
    item = poner_en_mesa(cosecha, 115)
    reconteo_viejo_del_deposito!(cosecha, mesa: 115, deposito: 53)

    get "/stocks/#{cosecha.id}", headers: auth_headers
    data = response.parsed_body['data']
    expect(data['mesas']).to eq([{ 'id' => item.id, 'sede' => 'Centro', 'cantidad' => 115.0 }])
    expect(data['reconteo_devolvible']).to eq(115.0)
    expect(data['en_deposito_g']).to eq(0.0)
  end

  it 'el stock de otra organización no se puede recontar' do
    ajeno = create(:club)
    st = ActsAsTenant.with_tenant(ajeno) { create(:stock, :externo, club: ajeno, sede: create(:sede, club: ajeno), cantidad: 50) }
    recontar(st, deposito: 10, mesas: {})
    expect(response).to have_http_status(:not_found)
    expect(st.reload.cantidad.to_f).to eq(50.0)
  end

  describe 'las otras puertas no bajan la mesa en silencio' do
    before { poner_en_mesa(externo, 100) } # 32 en el depósito

    it 'una merma de más que el depósito se rechaza y dice que es desde el mostrador' do
      post "/stocks/#{externo.id}/ajuste", params: { tipo: 'merma', gramos: -40, motivo: 'se rompió' },
                                           headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to include('mostrador')
      expect([externo.reload.cantidad.to_f, en_mesa(externo)]).to eq([132.0, 100.0])
    end

    it 'una merma dentro del depósito pasa y la mesa no se toca' do
      post "/stocks/#{externo.id}/ajuste", params: { tipo: 'merma', gramos: -30, motivo: 'se rompió' },
                                           headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok), response.body
      expect([externo.reload.cantidad.to_f, en_mesa(externo)]).to eq([102.0, 100.0])
    end

    it 'editar la cantidad por debajo de la mesa se rechaza' do
      put "/stocks/#{externo.id}", params: { stock: { cantidad: 90 } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect([externo.reload.cantidad.to_f, en_mesa(externo)]).to eq([132.0, 100.0])
    end

    it 'elaborar con más que lo del depósito se rechaza' do
      ActsAsTenant.with_tenant(club) { externo.update_columns(disponibilidad: 'ambas') }
      post "/stocks/#{externo.id}/producir",
           params: { gramos_usados: 40, forma_producto: 'aceite', cantidad_producida: 10, unidad: 'ml' },
           headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect([externo.reload.cantidad.to_f, en_mesa(externo)]).to eq([132.0, 100.0])
    end

    it 'finalizar el stock sí vacía la mesa (es cerrarlo a propósito)' do
      post "/stocks/#{externo.id}/descartar", params: { motivo: Stock::MOTIVOS_FINALIZACION.keys.first },
                                              headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok), response.body
      expect(en_mesa(externo)).to eq(0.0)
    end
  end
end
