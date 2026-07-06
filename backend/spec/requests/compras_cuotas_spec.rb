require 'rails_helper'

RSpec.describe 'Compras en cuotas', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }

  before { sign_in_as(admin) }

  def payload(extra = {})
    { compra_cuotas: {
        sede_id: sede.id, descripcion: 'Aire acondicionado', categoria: 'mantenimiento',
        monto_total_ars: 600_000, cuotas_total: 6, fecha_primera_cuota: Date.new(2026, 5, 1),
      }.merge(extra) }
  end

  it 'crea la compra y genera N movimientos egreso' do
    expect {
      post '/compras_cuotas', params: payload, headers: auth_headers
    }.to change(MovimientoContable, :count).by(6)
    expect(response).to have_http_status(:created)
    expect(CompraCuotas.count).to eq(1)
  end

  it 'borra la compra y todas sus cuotas' do
    post '/compras_cuotas', params: payload, headers: auth_headers
    compra = CompraCuotas.last
    expect {
      delete "/compras_cuotas/#{compra.id}", headers: auth_headers
    }.to change(MovimientoContable, :count).by(-6)
    expect(response).to have_http_status(:no_content)
  end

  it 'el libro (movimientos_contables#index) NO muestra las cuotas futuras' do
    # 3 cuotas: la 1 es de hoy (ya ocurrió), la 2 y 3 son de meses futuros.
    # Date.current = hoy en la zona del club (referencia contable correcta).
    post '/compras_cuotas', params: payload(cuotas_total: 3, fecha_primera_cuota: Date.current), headers: auth_headers
    expect(MovimientoContable.count).to eq(3)

    get '/movimientos_contables', headers: auth_headers
    expect(response).to have_http_status(:ok)
    body   = JSON.parse(response.body)
    cuotas = body['movimientos'].select { |m| m['descripcion'].to_s.include?('cuota') }
    expect(cuotas.size).to eq(1)
    expect(cuotas.first['descripcion']).to include('cuota 1/3')
  end

  it 'el dashboard (Últimos movimientos) tampoco muestra las cuotas futuras' do
    post '/compras_cuotas', params: payload(cuotas_total: 3, fecha_primera_cuota: Date.current), headers: auth_headers

    get '/movimientos_contables/dashboard', headers: auth_headers
    expect(response).to have_http_status(:ok)
    cuotas = JSON.parse(response.body)['ultimos_movimientos'].select { |m| m['descripcion'].to_s.include?('cuota') }
    expect(cuotas.size).to eq(1)
    expect(cuotas.first['descripcion']).to include('cuota 1/3')
  end

  it 'borrar una cuota desde el libro elimina la compra entera (todas las cuotas)' do
    post '/compras_cuotas', params: payload(cuotas_total: 3, fecha_primera_cuota: Date.current), headers: auth_headers
    compra    = CompraCuotas.last
    una_cuota = compra.movimientos_contables.order(:fecha).first

    expect {
      delete "/movimientos_contables/#{una_cuota.id}", headers: auth_headers
    }.to change(MovimientoContable, :count).by(-3)
    expect(response).to have_http_status(:no_content)
    expect(CompraCuotas.exists?(compra.id)).to be(false)
  end

  it 'aísla por tenant: no ve compras de otro club' do
    otro       = create(:club)
    otro_admin = create(:user, :admin, club: otro)
    otro_sede  = create(:sede, club: otro, created_by: otro_admin)
    CompraCuotas.create!(club: otro, sede: otro_sede, created_by: otro_admin,
                         descripcion: 'x', categoria: 'insumo', monto_total_ars: 100,
                         cuotas_total: 1, fecha_primera_cuota: Date.today)
    get '/compras_cuotas', headers: auth_headers
    expect(JSON.parse(response.body)).to eq([])
  end
end
