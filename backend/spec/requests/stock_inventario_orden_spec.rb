require 'rails_helper'

# ORDENAR LA TABLA DE INVENTARIO CLICKEANDO EL CABEZAL.
#
# El orden va en la CONSULTA y no en la pantalla: la tabla la pagina el servidor, así que ordenar
# en el navegador acomodaría los 25 renglones de la página y diría «ordenado por cantidad»
# mostrando los 25 de siempre. Eso se lee como una respuesta y no lo es.
RSpec.describe 'Inventario — ordenar por columna', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let!(:norte)  { create(:sede, club: club, created_by: admin, tipo: 'produccion', nombre: 'Zulú') }
  let!(:centro) { create(:sede, club: club, created_by: admin, tipo: 'mixta',      nombre: 'Alfa') }

  let(:kush)    { ActsAsTenant.with_tenant(club) { create(:genetica, club: club, nombre: 'Critical Kush') } }
  let(:amnesia) { ActsAsTenant.with_tenant(club) { create(:genetica, club: club, nombre: 'Amnesia Haze') } }

  # Uno de lote (la variedad sale del lote) y uno externo (sale del stock): la pantalla muestra la
  # del lote y cae a la del stock, y el orden tiene que hacer lo mismo.
  let!(:del_lote) do
    ActsAsTenant.with_tenant(club) do
      lote = create(:lote, club: club, genetica: kush, sala: create(:sala, club: club, sede: norte))
      create(:stock, club: club, sede: norte, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 900, cantidad_inicial: 1_000, estado: 'asignado',
                     numero_lote_producto: 'ST-26-0002', created_at: 3.days.ago)
    end
  end
  let!(:externo) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: centro, lote: nil, origen: 'compra_externa',
                     proveedor: 'Tercero SRL', genetica: amnesia, forma_producto: 'preroll',
                     unidad: 'un', cantidad: 40, cantidad_inicial: 50, estado: 'asignado',
                     numero_lote_producto: 'ST-26-0001', created_at: 1.day.ago)
    end
  end

  before { sign_in_as(admin) }

  def orden(campo = nil, dir = nil)
    get '/api/stocks/inventario', headers: auth_headers, params: { orden: campo, dir: dir }.compact
    JSON.parse(response.body)['stocks'].map { |s| s['numero_lote_producto'] }
  end

  it 'sin pedir nada, lo más nuevo primero — como venía' do
    expect(orden).to eq(%w[ST-26-0001 ST-26-0002])
  end

  it 'por sede, por su NOMBRE y no por su id' do
    expect(orden('sede', 'asc')).to eq(%w[ST-26-0001 ST-26-0002])   # Alfa, Zulú
    expect(orden('sede', 'desc')).to eq(%w[ST-26-0002 ST-26-0001])
  end

  # La del lote manda y cae a la del stock: si el orden mirara sólo `stocks.genetica_id`, el de
  # lote no tendría variedad para ordenar y caería al fondo siempre.
  it 'por variedad, mirando la del lote o la del stock' do
    expect(orden('genetica', 'asc')).to eq(%w[ST-26-0001 ST-26-0002])   # Amnesia, Critical
    expect(orden('genetica', 'desc')).to eq(%w[ST-26-0002 ST-26-0001])
  end

  it 'por cantidad actual' do
    expect(orden('actual', 'desc')).to eq(%w[ST-26-0002 ST-26-0001])   # 900, 40
    expect(orden('actual', 'asc')).to eq(%w[ST-26-0001 ST-26-0002])
  end

  # ORDENA POR LO QUE LA COLUMNA MUESTRA, que no es `stocks.cantidad`: «Actual» es el DISPONIBLE
  # —menos lo que está sobre la mesa del mostrador y lo reservado a un paciente—. Ordenando por la
  # columna de la base, el renglón que la pantalla muestra último aparecía primero. Germán,
  # probándolo: «funciona mal actual».
  describe 'con producto apartado' do
    before do
      ActsAsTenant.with_tenant(club) do
        paciente = create(:paciente, club: club)
        Reserva.create!(club: club, paciente: paciente, user: admin, stock: del_lote,
                        cantidad: 880, fecha_entrega_estimada: 3.days.from_now.to_date)
      end
    end

    it 'el que tiene casi todo apartado queda último, como lo muestra la tabla' do
      # 900 en la fila, 880 reservados a un paciente: quedan 20 disponibles contra los 40 del otro.
      expect(del_lote.reload.cantidad_disponible_real.to_f).to eq(20.0)

      expect(orden('actual', 'desc')).to eq(%w[ST-26-0001 ST-26-0002])
      expect(orden('actual', 'asc')).to  eq(%w[ST-26-0002 ST-26-0001])
    end

    it 'y la paginación sigue siendo del servidor: la página 1 trae el primero de TODOS' do
      get '/api/stocks/inventario', headers: auth_headers,
          params: { orden: 'actual', dir: 'desc', page: 1, per_page: 1 }
      body = JSON.parse(response.body)
      expect(body['stocks'].map { |s| s['numero_lote_producto'] }).to eq(%w[ST-26-0001])
      expect(body['meta']['total']).to eq(2)

      get '/api/stocks/inventario', headers: auth_headers,
          params: { orden: 'actual', dir: 'desc', page: 2, per_page: 1 }
      expect(JSON.parse(response.body)['stocks'].map { |s| s['numero_lote_producto'] }).to eq(%w[ST-26-0002])
    end
  end

  it 'por cantidad inicial, por código, por tipo y por fecha' do
    expect(orden('cantidad_inicial', 'desc')).to eq(%w[ST-26-0002 ST-26-0001])
    expect(orden('codigo', 'asc')).to eq(%w[ST-26-0001 ST-26-0002])
    expect(orden('tipo', 'asc')).to eq(%w[ST-26-0002 ST-26-0001])      # flor_seca, preroll
    expect(orden('ingreso', 'asc')).to eq(%w[ST-26-0002 ST-26-0001])
  end

  # El que no tiene precio queda al final en los dos sentidos: ordenando por precio se busca el
  # número, y los vacíos arriba taparían la primera pantalla.
  it 'por precio sugerido, y el que no tiene queda al final aunque se ordene al revés' do
    ActsAsTenant.with_tenant(club) do
      externo.update_column(:precio_sugerido_ars, 4_000)
      del_lote.update_column(:precio_sugerido_ars, 3_000)
    end
    expect(orden('precio', 'desc')).to eq(%w[ST-26-0001 ST-26-0002])
    expect(orden('precio', 'asc')).to  eq(%w[ST-26-0002 ST-26-0001])

    ActsAsTenant.with_tenant(club) { del_lote.update_column(:precio_sugerido_ars, nil) }
    expect(orden('precio', 'asc')).to  eq(%w[ST-26-0001 ST-26-0002])
    expect(orden('precio', 'desc')).to eq(%w[ST-26-0001 ST-26-0002])
  end

  # «Depósito» es el frasco menos la mesa, NO la cantidad inicial: el de lote entró con 1.000 y
  # tiene 900, 880 de ellos sobre la mesa — en el depósito quedan 20, contra los 40 del externo.
  # Ordenando por lo que entró, el de lote saldría primero.
  describe 'por depósito y por reserva' do
    before do
      ActsAsTenant.with_tenant(club) do
        MostradorItem.create!(club: club, mostrador: centro.mostrador!, stock: del_lote, cantidad: 880)
        Reserva.create!(club: club, paciente: create(:paciente, club: club), user: admin,
                        stock: del_lote, cantidad: 15, fecha_entrega_estimada: 3.days.from_now.to_date)
      end
    end

    it 'el depósito es lo que no está sobre la mesa, y la respuesta lo trae' do
      expect(orden('deposito', 'desc')).to eq(%w[ST-26-0001 ST-26-0002])   # 40, 20
      expect(orden('deposito', 'asc')).to  eq(%w[ST-26-0002 ST-26-0001])

      get '/api/stocks/inventario', headers: auth_headers
      fila = JSON.parse(response.body)['stocks'].find { |s| s['numero_lote_producto'] == 'ST-26-0002' }
      expect(fila['en_deposito_g']).to eq(20.0)
      expect(fila['en_mostrador_g']).to eq(880.0)
      expect(fila['reservado']).to eq(15.0)
      # Depósito + mesa = lo que hay; la reserva está adentro de la mesa, no se suma aparte.
      expect(fila['en_deposito_g'] + fila['en_mostrador_g']).to eq(fila['cantidad'])
    end

    # Los KPIs del Depósito: dónde está la flor, sumado en el backend. Sólo flor seca (el
    # externo es preroll, no suma gramos).
    it 'los totales dicen cuánta flor está guardada y cuánta sobre la mesa' do
      get '/api/stocks/inventario', headers: auth_headers
      totales = JSON.parse(response.body)['totales']
      expect(totales['en_deposito_g']).to eq(20.0)
      expect(totales['en_mesa_g']).to eq(880.0)
      expect(totales['reservado_g']).to eq(15.0)
    end

    it 'por reserva' do
      expect(orden('reserva', 'desc')).to eq(%w[ST-26-0002 ST-26-0001])   # 15, 0
      expect(orden('reserva', 'asc')).to  eq(%w[ST-26-0001 ST-26-0002])
    end
  end

  it 'por lote, y el que no tiene queda al final aunque se ordene al revés' do
    expect(orden('lote', 'asc')).to  eq(%w[ST-26-0002 ST-26-0001])
    expect(orden('lote', 'desc')).to eq(%w[ST-26-0002 ST-26-0001])     # el externo, sin lote, no sube
  end

  # El parámetro entra en un ORDER BY: si no fuera lista blanca, cualquiera escribe SQL ahí.
  it 'una columna inventada no ordena por ella ni rompe nada' do
    expect(orden('cantidad; DROP TABLE stocks', 'asc')).to eq(%w[ST-26-0001 ST-26-0002])
    expect(Stock.table_exists?).to be true
  end

  it 'y una dirección inventada cae a descendente' do
    get '/api/stocks/inventario', headers: auth_headers, params: { orden: 'actual', dir: 'raro' }
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['stocks'].first['numero_lote_producto']).to eq('ST-26-0002')
  end
end
