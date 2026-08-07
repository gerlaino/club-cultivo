require 'rails_helper'

# Buscador del POS multi-depósito: qué puede cobrar el mostrador y quién lo ve.
RSpec.describe 'Bar — vendibles de cualquier depósito', type: :request do
  let(:club)  { create(:club, features: { 'bar' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'social') }
  let(:bar)   { create(:barra, club: club, sede: sede) }

  let!(:cerveza) { create(:bar_producto, club: club, bar: bar, nombre: 'Cerveza', stock: 20, precio_ars: 2500) }
  let!(:remera)  { club.insumos.create!(nombre: 'Remera club', unidad_medida: 'unidad', stock_actual: 10, costo_promedio_ars: 8000) }
  let!(:agua)    do
    create(:stock, :externo, club: club, sede: sede, cantidad: 24, unidad: 'un',
                             costo_unitario_ars: 700, precio_sugerido_ars: 1200, descripcion: 'Agua saborizada')
  end
  let(:lote) { create(:lote, club: club) }
  let!(:flor) do
    create(:stock, club: club, sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca',
                   cantidad: 100, precio_sugerido_ars: 3000, descripcion: 'Kush')
  end

  def buscar(q = nil, user: admin)
    sign_in_as(user)
    get "/bares/#{bar.id}/vendibles", params: (q ? { q: q } : {}), headers: auth_headers
    JSON.parse(response.body)['resultados']
  end

  it 'lista productos del bar e insumos de otros depósitos' do
    res = buscar
    expect(res.map { |r| r['vendible_type'] }.uniq).to contain_exactly('BarProducto', 'Insumo')
    expect(res.map { |r| r['nombre'] }.join).to include('Cerveza', 'Remera')
  end

  # Una sola puerta de salida para lo trazable: la dispensación.
  it 'nunca ofrece stock — ni flor ni externo' do
    nombres = buscar.map { |r| r['nombre'] }.join
    expect(nombres).not_to include('Kush')  # propio
    expect(nombres).not_to include('Agua')  # externo (merch/bebida)
  end

  it 'marca los ítems sin precio propio como requiere_precio' do
    fila = buscar('Remera').find { |r| r['vendible_type'] == 'Insumo' }
    expect(fila['requiere_precio']).to be true
    expect(fila['deposito']).to eq('cultivo')
    expect(fila['disponible']).to eq(10.0)
  end

  it 'al dispensador solo le muestra lo que tiene precio cargado' do
    disp = create(:user, :dispensador, club: club)
    res = buscar(nil, user: disp)
    expect(res.map { |r| r['nombre'] }.join).not_to include('Remera')
    expect(res.map { |r| r['nombre'] }.join).to include('Cerveza')
    expect(res.map { |r| r['costo_ars'] }.compact).to be_empty # sin plata para el dispensador
  end

  it 'no muestra mercadería de otro club' do
    otro = create(:club, features: { 'bar' => true })
    ActsAsTenant.with_tenant(otro) do
      otro.insumos.create!(nombre: 'Remera ajena', unidad_medida: 'unidad', stock_actual: 5)
    end
    expect(buscar('Remera').map { |r| r['nombre'] }.join).not_to include('ajena')
  end

  it 'el auditor no puede usar el mostrador' do
    aud = create(:user, :auditor, club: club)
    sign_in_as(aud)
    get "/bares/#{bar.id}/vendibles", headers: auth_headers
    expect(response).to have_http_status(:forbidden)
  end
end

# El cierre de período no puede dejar al mostrador sin cobrar (ver cierre_contable_spec).
RSpec.describe 'Bar — venta con período contable cerrado', type: :request do
  let(:club)  { create(:club, features: { 'bar' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'social') }
  let(:bar)   { create(:barra, club: club, sede: sede) }
  let!(:cerveza) { create(:bar_producto, club: club, bar: bar, nombre: 'Cerveza', stock: 20, precio_ars: 2500) }

  before { sign_in_as(admin) }

  it 'sigue cobrando con el período cerrado hasta ayer' do
    club.update!(contabilidad_cerrada_hasta: Time.zone.today - 1)
    post "/bares/#{bar.id}/ventas",
         params: { lineas: [{ vendible_type: 'BarProducto', vendible_id: cerveza.id, cantidad: 1 }], medio_pago: 'efectivo' },
         headers: auth_headers, as: :json
    expect(response).to have_http_status(:created)
    expect(cerveza.reload.stock).to eq(19)
  end

  it 'si el período llegara a incluir hoy, explica el problema en vez de romper' do
    club.update!(contabilidad_cerrada_hasta: Time.zone.today) # estado heredado: la UI ya no lo permite
    post "/bares/#{bar.id}/ventas",
         params: { lineas: [{ vendible_type: 'BarProducto', vendible_id: cerveza.id, cantidad: 1 }], medio_pago: 'efectivo' },
         headers: auth_headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to include('período cerrado')
    expect(cerveza.reload.stock).to eq(20) # la transacción se revirtió entera
  end
end
