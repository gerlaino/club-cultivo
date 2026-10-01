require 'rails_helper'

# AC (Germán, 1-oct-2026): el movimiento de stock que deja una dispensa lleva la fecha DE LA
# DISPENSA, no la del día en que se cargó. Una entrega del 10 de agosto cargada hoy es una salida
# de agosto en todo lo que corta por período (Pérdidas, trazabilidad, informe de stock).
RSpec.describe 'Fecha del movimiento de stock de una dispensa', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)     { create(:lote, club: club, sala: sala) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }
  let!(:cc)      { paciente.cuenta_corriente!.tap { |c| c.update!(saldo_disponible: 0, limite_credito: 100_000) } }
  let!(:stock)   { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100, precio_sugerido_ars: 100) }
  let!(:otro)    { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100, precio_sugerido_ars: 100) }
  let(:hace_40)  { Time.zone.today - 40 }

  before { sign_in_as(admin) }

  def crear(fecha, extra = {})
    post "/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { stock_id: stock.id, cantidad: 10, medio_pago: 'efectivo', fecha_dispensacion: fecha.to_s }.merge(extra) },
         headers: auth_headers, as: :json
    expect(response).to have_http_status(:created), response.body
    Dispensacion.last
  end
  def fechas(d) = ActsAsTenant.with_tenant(club) { StockMovimiento.where(dispensacion_id: d.id, tipo: 'dispensacion').pluck(:fecha) }

  it 'una dispensa vieja cargada hoy: el movimiento queda en su día' do
    expect(fechas(crear(hace_40))).to eq([hace_40])
  end

  it 'una dispensa de hoy, hoy' do
    expect(fechas(crear(Time.zone.today))).to eq([Time.zone.today])
  end

  it 'multi-producto: cada línea, con la fecha de la dispensa' do
    d = crear(hace_40, stock_id: nil, cantidad: nil,
                       items: [{ stock_id: stock.id, cantidad: 5 }, { stock_id: otro.id, cantidad: 3 }])
    expect(fechas(d)).to eq([hace_40, hace_40])
  end

  it 'corregirle sólo la fecha mueve el movimiento al día nuevo' do
    d = crear(Time.zone.today)
    patch "/dispensaciones/#{d.id}", params: { dispensacion: { fecha_dispensacion: hace_40.to_s } }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok), response.body
    expect(fechas(d)).to eq([hace_40])
  end

  it 'editarla con cambio de cantidad y de fecha: el movimiento rehecho trae la fecha nueva' do
    d = crear(Time.zone.today)
    patch "/dispensaciones/#{d.id}", params: { dispensacion: { cantidad: 20, aporte_socio_ars: 2000, fecha_dispensacion: hace_40.to_s } },
                                     headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok), response.body
    expect(fechas(d)).to eq([hace_40])
  end

  it 'lo que corta por período la ubica en su mes: no es salida de este mes' do
    d = crear(hace_40)
    este_mes = ActsAsTenant.with_tenant(club) do
      StockMovimiento.where(dispensacion_id: d.id).en_periodo(Time.zone.today.beginning_of_month, Time.zone.today).count
    end
    expect(este_mes).to eq(0) # hace 40 días es siempre otro mes
  end
end
