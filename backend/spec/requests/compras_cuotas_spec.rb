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
