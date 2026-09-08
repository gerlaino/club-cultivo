require 'rails_helper'

# LO QUE TENÍA QUE HABER CONTRA LO QUE SE CONTÓ, día por día y PRODUCTO POR PRODUCTO.
#
# Idea de Germán, y resuelve el problema de fondo: en un total hay que sumar gramos de flor con
# unidades de preroll, y eso da un número que no significa nada. Por producto no hay nada que
# sumar.
#
# Y cada uno con SU escala en la pantalla. Los dos casos que importan y que este spec fija:
#   · EL DESPLOME — 23 g de golpe un día. Se ve en cualquier gráfico.
#   · EL GOTEO — un gramo casi todos los días. En un eje compartido con la flor a 400 g NO EXISTE,
#     y es el que sangra sin disparar ninguna alarma.
RSpec.describe 'La evolución del mostrador, producto por producto', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:ana)   { create(:user, :dispensador, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'social', created_by: admin) }
  let(:lote)  { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }

  def stock!(nombre, unidad: 'g', costo: 500)
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca',
                     unidad: unidad, cantidad: 5_000, estado: 'asignado', disponibilidad: 'ambas',
                     costo_unitario_ars: costo, numero_lote_producto: nombre)
    end
  end

  let!(:kush)     { stock!('ST-KUSH') }
  let!(:northern) { stock!('ST-NORTH') }

  # Un cierre por día, con lo que la mesa decía y lo que se contó.
  # El hash va SIEMPRE entre llaves: con un keyword (`hora:`) en la firma, Ruby toma un hash
  # suelto como keywords y falla con «wrong number of arguments».
  def cerrar_dia!(fecha, conteos, hora: 8)
    ActsAsTenant.with_tenant(club) do
      # `estado: 'cerrado'` y no sólo `cerrado_at`: hay un índice único de un turno ABIERTO por
      # mostrador, así que sin el estado el segundo día choca contra el primero.
      t = TurnoMostrador.create!(club: club, mostrador: sede.mostrador!, abierto_por: ana,
                                 estado: 'cerrado', abierto_at: fecha.to_time,
                                 cerrado_at: fecha.to_time + hora.hours, cerrado_por: ana)
      conteos.each do |st, (esperado, contado)|
        TurnoMostradorItem.create!(club: club, turno_mostrador: t, stock: st,
                                   esperado_cierre: esperado, cantidad_cierre: contado)
      end
      t
    end
  end

  before do
    # El desplome: la Kush cuadra tres días y el cuarto faltan 23.
    # El goteo: la Northern pierde 1 o 2 g casi todos los días.
    cerrar_dia!(Date.current - 3, { kush => [46, 46], northern => [120, 119] })
    cerrar_dia!(Date.current - 2, { kush => [46, 46], northern => [120, 118] })
    cerrar_dia!(Date.current - 1, { kush => [46, 46], northern => [120, 120] })
    cerrar_dia!(Date.current,     { kush => [46, 23], northern => [120, 119] })
    sign_in_as(admin)
  end

  def evolucion
    get "/sedes/#{sede.id}/mostrador/evolucion",
        params: { desde: (Date.current - 7).to_s, hasta: Date.current.to_s }, headers: auth_headers
    JSON.parse(response.body)
  end

  it 'devuelve una serie por producto, no un total' do
    productos = evolucion['productos']
    expect(productos.map { |p| p['stock_id'] }).to match_array([kush.id, northern.id])
  end

  it 'cada punto trae lo que tenía que haber y lo que se contó' do
    serie = evolucion['productos'].find { |p| p['stock_id'] == kush.id }
    expect(serie['puntos'].map { |p| [p['esperado'], p['contado']] })
      .to eq([[46.0, 46.0], [46.0, 46.0], [46.0, 46.0], [46.0, 23.0]])
  end

  # EL GOTEO: cuatro gramos repartidos en cuatro días. Sin serie propia, esto no se ve en ningún
  # lado — el total del mostrador lo tapa y ningún día dispara una alarma.
  it 'el que gotea aparece con su propio total, aunque ningún día llame la atención' do
    serie = evolucion['productos'].find { |p| p['stock_id'] == northern.id }
    expect(serie['falta']).to eq(4.0)
    expect(serie['peor']['falta']).to eq(2.0)
  end

  # Ordenados por lo que COSTÓ lo que falta: lo que más pesa no es lo que más duele.
  it 'ordena por plata perdida, no por gramos' do
    expect(evolucion['productos'].first['stock_id']).to eq(kush.id)
  end

  it 'los que nunca tuvieron diferencia viajan marcados, para que la pantalla los pliegue' do
    otro = stock!('ST-OK')
    cerrar_dia!(Date.current, { otro => [200, 200] }, hora: 20)

    serie = evolucion['productos'].find { |p| p['stock_id'] == otro.id }
    expect(serie['sin_diferencias']).to be(true)
    expect(evolucion['productos'].last['stock_id']).to eq(otro.id)
  end

  # Dos cierres el mismo día se pisarían en el eje: el gráfico es «cómo terminó cada día».
  it 'con varios cierres en un día toma el último' do
    # Más tarde que el de `before`: «el último» tiene que ser inequívoco, y con la misma hora
    # el test pasaría o fallaría según el orden en que salgan de la base.
    cerrar_dia!(Date.current, { kush => [23, 20] }, hora: 20)
    serie = evolucion['productos'].find { |p| p['stock_id'] == kush.id }
    hoy = serie['puntos'].select { |p| p['fecha'] == Date.current.to_s }

    expect(hoy.size).to eq(1)
    expect(hoy.first['contado']).to eq(20.0)
  end

  it 'respeta el rango pedido' do
    get "/sedes/#{sede.id}/mostrador/evolucion",
        params: { desde: Date.current.to_s, hasta: Date.current.to_s }, headers: auth_headers
    serie = JSON.parse(response.body)['productos'].find { |p| p['stock_id'] == kush.id }
    expect(serie['puntos'].size).to eq(1)
  end

  it 'el que atiende no lo mira: es información de gestión' do
    sign_in_as(ana)
    get "/sedes/#{sede.id}/mostrador/evolucion", headers: auth_headers
    expect(response).to have_http_status(:forbidden)
  end
end
