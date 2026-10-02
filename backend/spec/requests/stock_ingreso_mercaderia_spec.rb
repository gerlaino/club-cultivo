require 'rails_helper'

# AC (socio de Germán, 1-oct-2026): el informe de stock externo tiene que decir lo que ENTRÓ en el
# mes —«en septiembre se ingresaron estos gramos de estas genéticas»—. En octubre le carga más a
# los stocks que ya traía de septiembre («es la misma» mercadería: se suma al mismo stock), y eso
# tiene que aparecer en octubre aunque el stock se haya creado en septiembre.
#
# «Entró mercadería» es la puerta: `POST /stocks/:id/ajuste` con `tipo: ingreso`, con la fecha en
# que entró (el informe de septiembre se arma en octubre).
RSpec.describe 'POST /stocks/:id/ajuste — entró mercadería', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin, tipo: 'mixta') }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:gorilla) { ActsAsTenant.with_tenant(club) { create(:genetica, club: club, nombre: 'Gorilla') } }

  let!(:externo) do
    ActsAsTenant.with_tenant(club) do
      Stock.create!(sede: sede, origen: 'compra_externa', proveedor: 'Coop Sur', genetica: gorilla,
                    forma_producto: 'flor_seca', unidad: 'g', cantidad: 100, estado: 'asignado')
    end
  end

  def json = JSON.parse(response.body)
  def ingresar(stock, **body) = post("/stocks/#{stock.id}/ajuste", params: { tipo: 'ingreso', **body }, headers: auth_headers, as: :json)

  before { sign_in_as(admin) }

  it 'suma al mismo stock y deja un movimiento `ingreso` con la fecha en que entró' do
    ingresar(externo, gramos: 50, fecha: '2026-09-28', motivo: 'Remito 0012')

    expect(response).to have_http_status(:ok), response.body
    expect(externo.reload.cantidad.to_f).to eq(150.0)
    mov = externo.stock_movimientos.last
    expect(mov).to have_attributes(tipo: 'ingreso', fecha: Date.new(2026, 9, 28))
    expect(mov.gramos.to_f).to eq(50.0)
    expect(mov.notas).to include('Remito 0012')
  end

  it 'no toca la cantidad inicial: es lo que entró AL CREARLO' do
    ingresar(externo, gramos: 50)
    expect(externo.reload.cantidad_inicial.to_f).to eq(100.0)
  end

  it 'sin fecha, entró hoy' do
    ingresar(externo, gramos: 10)
    expect(externo.stock_movimientos.last.fecha).to eq(Time.zone.today)
  end

  it 'no acepta una fecha futura' do
    ingresar(externo, gramos: 10, fecha: (Time.zone.today + 1).iso8601)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(externo.reload.cantidad.to_f).to eq(100.0)
  end

  it 'no acepta cero ni negativo' do
    ingresar(externo, gramos: 0)
    expect(response).to have_http_status(:unprocessable_entity)
    ingresar(externo, gramos: -5)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(externo.reload.cantidad.to_f).to eq(100.0)
  end

  it 'a un stock de cosecha no le entra mercadería: sus gramos salen del pesaje' do
    de_cosecha = ActsAsTenant.with_tenant(club) do
      Stock.create!(sede: sede, lote: create(:lote, club: club, sala: sala), origen: 'lote',
                    forma_producto: 'flor_seca', unidad: 'g', cantidad: 100, estado: 'asignado')
    end
    ingresar(de_cosecha, gramos: 50)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(de_cosecha.reload.cantidad.to_f).to eq(100.0)
    expect(de_cosecha.stock_movimientos.where(tipo: 'ingreso')).to be_empty
  end

  it 'un frasco externo que se había vaciado vuelve a estar disponible' do
    externo.update_columns(cantidad: 0, estado: 'agotado')
    ingresar(externo, gramos: 30)

    expect(response).to have_http_status(:ok), response.body
    expect(externo.reload).to have_attributes(estado: 'asignado')
    expect(externo.cantidad.to_f).to eq(30.0)
  end

  it 'la trazabilidad del frasco cierra: lo que entró después cuenta como entrada' do
    ingresar(externo, gramos: 50)
    get "/stocks/#{externo.id}/trazabilidad", headers: auth_headers

    expect(response).to have_http_status(:ok), response.body
    expect(json.dig('totales', 'entradas_g')).to eq(50.0)
    expect(json.dig('totales', 'sin_explicar_g')).to eq(0.0)
    expect(json['frase']).to include('Después entraron 50 g más en 1 ingreso')
  end

  it 'aislamiento: no se le puede ingresar a un stock de otra organización' do
    otra  = create(:club)
    ajeno = ActsAsTenant.with_tenant(otra) do
      Stock.create!(sede: create(:sede, club: otra, created_by: create(:user, :admin, club: otra)),
                    genetica: create(:genetica, club: otra), origen: 'compra_externa', proveedor: 'Otro',
                    forma_producto: 'flor_seca', unidad: 'g', cantidad: 10)
    end
    ingresar(ajeno, gramos: 50)

    expect(response.status).to be_in([403, 404])
    expect(ajeno.reload.cantidad.to_f).to eq(10.0)
  end
end
