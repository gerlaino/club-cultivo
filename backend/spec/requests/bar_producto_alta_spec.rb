require 'rails_helper'

# Alta unificada del producto del bar: crear + carga inicial (stock + costo + egreso "Bar / Salón")
# en un solo paso, sin pasar por "Comprar". Resuelve la friction de "crear en 0 y después reponer".
RSpec.describe 'Bar — alta unificada de producto', type: :request do
  let(:club)  { create(:club, features: { 'bar' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'social') }
  let(:bar)   { create(:barra, club: club, sede: sede) }

  before { sign_in_as(admin) }

  def crear(bar_producto:, carga_inicial: nil)
    params = { bar_producto: bar_producto }
    params[:carga_inicial] = carga_inicial if carga_inicial
    post "/bares/#{bar.id}/productos", params: params, headers: auth_headers, as: :json
  end

  it 'crea el producto y registra la carga inicial en un paso (stock + costo + egreso "bar")' do
    expect {
      crear(bar_producto: { nombre: 'Coca', categoria: 'bebida', precio_ars: 1500, codigo_barras: '7790895000997' },
            carga_inicial: { cantidad: 50, costo_total_ars: 60_000, proveedor: 'Distribuidora X' })
    }.to change { ActsAsTenant.with_tenant(club) { club.movimientos_contables.where(categoria: 'bar', tipo: 'egreso').count } }.by(1)

    expect(response).to have_http_status(:created)
    prod = ActsAsTenant.with_tenant(club) { bar.bar_productos.find_by(codigo_barras: '7790895000997') }
    expect(prod.stock).to eq(50)
    expect(prod.costo_ars).to eq(1_200) # 60000 / 50
  end

  it 'sin carga inicial, crea el producto en 0 (para pre-cargar catálogo)' do
    crear(bar_producto: { nombre: 'Agua', categoria: 'bebida', precio_ars: 800 })
    expect(response).to have_http_status(:created)
    expect(ActsAsTenant.with_tenant(club) { bar.bar_productos.find_by(nombre: 'Agua').stock }).to eq(0)
  end

  it 'rechaza carga inicial con cantidad pero sin costo (no hay stock sin costo)' do
    crear(bar_producto: { nombre: 'Fanta', categoria: 'bebida', precio_ars: 1000 },
          carga_inicial: { cantidad: 10, costo_total_ars: 0 })
    expect(response).to have_http_status(:unprocessable_entity)
    # No quedó ni el producto ni el asiento a medias (transacción).
    expect(ActsAsTenant.with_tenant(club) { bar.bar_productos.find_by(nombre: 'Fanta') }).to be_nil
  end
end
