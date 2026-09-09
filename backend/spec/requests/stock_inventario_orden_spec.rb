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

  it 'por cantidad inicial, por código, por tipo y por fecha' do
    expect(orden('cantidad_inicial', 'desc')).to eq(%w[ST-26-0002 ST-26-0001])
    expect(orden('codigo', 'asc')).to eq(%w[ST-26-0001 ST-26-0002])
    expect(orden('tipo', 'asc')).to eq(%w[ST-26-0002 ST-26-0001])      # flor_seca, preroll
    expect(orden('ingreso', 'asc')).to eq(%w[ST-26-0002 ST-26-0001])
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
