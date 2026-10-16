require 'rails_helper'

# AC (Germán, 15-oct-2026): «no pueden haber estos errores». Los dos que salieron de Mitocondria
# venían de CARGAR HISTORIA (stock dado de alta hoy, dispensas con su fecha real y editadas más de
# una vez), un camino poco usado y poco probado. Acá se carga historia como lo hizo Javi y se
# cruza el mismo número en los tres lugares: el saldo del stock, el informe de stock y el de
# dispensaciones. Mismo nombre, mismo número.
RSpec.describe 'Cargar historia: el stock y los dos informes dicen lo mismo', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }
  let!(:frasco) do
    Stock.create!(sede: sede, origen: 'compra_externa', proveedor: 'Interno', forma_producto: 'flor_seca',
                  unidad: 'g', cantidad: 50, precio_sugerido_ars: 100)
  end

  let(:mes_pasado) { Time.zone.today.prev_month }
  let(:pasado)     { mes_pasado.beginning_of_month..mes_pasado.end_of_month }
  let(:este)       { Time.zone.today.beginning_of_month..Time.zone.today }

  before do
    sign_in_as(admin)
    paciente.cuenta_corriente!.tap { |c| c.update!(saldo_disponible: 0, limite_credito: 100_000) }
  end

  def dispensar(cantidad, fecha)
    post "/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { stock_id: frasco.id, cantidad: cantidad, medio_pago: 'efectivo', fecha_dispensacion: fecha.to_s } },
         as: :json
    expect(response).to have_http_status(:created), response.body
    Dispensacion.last
  end

  def editar(d, cantidad)
    patch "/dispensaciones/#{d.id}", params: { dispensacion: { cantidad: cantidad, aporte_socio_ars: cantidad * 100 } }, as: :json
    expect(response).to have_http_status(:ok), response.body
  end

  def inventario(r)  = ActsAsTenant.with_tenant(club) { Informes::Inventario.new(club: club, desde: r.first, hasta: r.last).call }
  def fila(r)        = inventario(r)[:stocks].find { |f| f[:id] == frasco.id }
  def salio_g(r)     = ActsAsTenant.with_tenant(club) { Informes::Dispensaciones.new(club: club, desde: r.first, hasta: r.last).call }[:salio][:por_unidad].find { |u| u[:unidad] == 'g' }&.dig(:cantidad).to_f
  def cierra?(f)     = (f[:habia] + f[:ingreso] - f[:dispensado] - f[:merma] - f[:otras_salidas] + f[:ajustes] - f[:quedaba]).abs < 0.01

  before do
    d = dispensar(10, pasado.first + 3)
    editar(d, 12)                          # editada dos veces: el caso del bug del 2-sep
    editar(d, 15)
    dispensar(20, pasado.first + 10)
    dispensar(5, Time.zone.today)
  end

  it 'el saldo del stock es lo que entró menos lo dispensado' do
    expect(frasco.reload.cantidad.to_f).to eq(10.0)  # 50 − 15 − 20 − 5
  end

  it 'el mes de la historia: entró y salió, cierra, y lo dispensado es lo del informe de dispensaciones' do
    f = fila(pasado)
    expect(f).to include(habia: 0.0, ingreso: 50.0, dispensado: 35.0, quedaba: 15.0)
    expect(f[:descuadre]).to be_nil
    expect(cierra?(f)).to be(true)
    expect(f[:dispensado]).to eq(salio_g(pasado))
  end

  it 'este mes (el del alta): arranca con lo que quedó, no como un ingreso sin salida' do
    f = fila(este)
    expect(f).to include(habia: 15.0, ingreso: 0.0, dispensado: 5.0, quedaba: 10.0)
    expect(f[:descuadre]).to be_nil
    expect(f[:dispensado]).to eq(salio_g(este))
    expect(f[:quedaba]).to eq(frasco.reload.cantidad.to_f)
  end

  it 'los dos meses juntos: todo lo que entró, todo lo que salió y el saldo de hoy' do
    f = fila(pasado.first..Time.zone.today)
    expect(f).to include(habia: 0.0, ingreso: 50.0, dispensado: 40.0, quedaba: 10.0)
    expect(f[:descuadre]).to be_nil
    expect(f[:dispensado]).to eq(salio_g(pasado.first..Time.zone.today))
  end
end
