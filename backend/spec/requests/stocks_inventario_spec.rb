require 'rails_helper'

# Tabla de inventario paginada y filtrable de /admin/stock.
RSpec.describe 'GET /stocks/inventario', type: :request do
  include AuthHelpers

  let!(:club)  { create(:club) }
  let!(:admin) { create(:user, :admin, club: club) }
  let!(:sede)  { create(:sede, club: club) }
  let!(:sede2) { create(:sede, club: club) }
  let!(:lote)  { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) }

  before { sign_in_as(admin) }

  def stock!(attrs = {})
    create(:stock, { club: club, sede: sede, lote: lote, cantidad: 100 }.merge(attrs))
  end

  it 'devuelve stocks paginados con meta y totales' do
    3.times { stock! }
    get '/stocks/inventario', params: { per_page: 2 }, headers: auth_headers
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body['stocks'].size).to eq(2)
    expect(body['meta']['total']).to eq(3)
    expect(body['meta']['per_page']).to eq(2)
    expect(body['totales']['total_g']).to eq(300.0)
    expect(body['totales']['items']).to eq(3)
  end

  it 'filtra por forma_producto' do
    stock!(forma_producto: 'flor_seca')
    create(:stock, :externo, club: club, sede: sede, forma_producto: 'aceite', cantidad: 5)
    get '/stocks/inventario', params: { forma_producto: 'aceite' }, headers: auth_headers
    body = JSON.parse(response.body)
    expect(body['stocks'].map { |s| s['forma_producto'] }.uniq).to eq(['aceite'])
    expect(body['meta']['total']).to eq(1)
  end

  it 'filtra por sede' do
    stock!(sede: sede)
    stock!(sede: sede2)
    get '/stocks/inventario', params: { sede_id: sede2.id }, headers: auth_headers
    body = JSON.parse(response.body)
    expect(body['stocks'].map { |s| s['sede_id'] }.uniq).to eq([sede2.id])
  end

  it 'sede_id=pool devuelve solo stock sin sede' do
    stock!(sede: sede)
    pool = stock!(sede: nil, estado: 'pendiente_asignacion')
    get '/stocks/inventario', params: { sede_id: 'pool' }, headers: auth_headers
    body = JSON.parse(response.body)
    expect(body['stocks'].map { |s| s['id'] }).to eq([pool.id])
  end

  it 'no incluye stock agotado (cantidad 0)' do
    stock!(cantidad: 100)
    stock!(cantidad: 0, estado: 'agotado')
    get '/stocks/inventario', headers: auth_headers
    body = JSON.parse(response.body)
    expect(body['meta']['total']).to eq(1)
  end

  it 'total_g = disponible real: resta lo reservado (apartado), no la cantidad cruda' do
    s = stock!(forma_producto: 'flor_seca', cantidad: 100)
    paciente = create(:paciente, club: club, created_by: admin)
    Reserva.create!(club: club, paciente: paciente, user: admin, stock: s, estado: 'pendiente',
                    cantidad: 25, fecha_entrega_estimada: 3.days.from_now.to_date)
    get '/stocks/inventario', headers: auth_headers
    body = JSON.parse(response.body)
    expect(body['totales']['total_g']).to eq(75.0)      # 100 - 25 reservado
    expect(body['totales']['reservado_g']).to eq(25.0)  # KPI de reservado (flor)
  end

  it 'derivados_items cuenta los ítems no-flor y NO los suma a los gramos de flor' do
    stock!(forma_producto: 'flor_seca', cantidad: 100)
    create(:stock, :externo, club: club, sede: sede, forma_producto: 'preroll', cantidad: 30)
    create(:stock, :externo, club: club, sede: sede, forma_producto: 'hash',    cantidad: 12)
    get '/stocks/inventario', headers: auth_headers
    body = JSON.parse(response.body)
    expect(body['totales']['total_g']).to eq(100.0)     # solo flor seca
    expect(body['totales']['derivados_items']).to eq(2) # preroll + hash
  end

  it 'no muestra stock de otro club (aislamiento de tenant)' do
    otro = create(:club)
    ActsAsTenant.with_tenant(otro) do
      o_sede = create(:sede, club: otro)
      o_lote = create(:lote, club: otro, sala: create(:sala, club: otro, sede: o_sede))
      create(:stock, club: otro, sede: o_sede, lote: o_lote, cantidad: 999)
    end
    stock!(cantidad: 50)
    get '/stocks/inventario', headers: auth_headers
    body = JSON.parse(response.body)
    expect(body['meta']['total']).to eq(1)
    expect(body['totales']['total_g']).to eq(50.0)
  end
end
