require 'rails_helper'

# AC (Germán, 12-oct-2026): una receta no se traba porque el producto no esté cargado — se da de
# alta sin compra. Ese alta NO genera registro contable ni stock (la pantalla lo avisa); la compra
# tiene su puerta en Contabilidad. Lo puede hacer quien arma recetas (cultivador), no quien atiende.
RSpec.describe 'Alta de un producto sin compra', type: :request do
  include AuthHelpers
  def json = JSON.parse(response.body)

  let(:club)       { create(:club, features: { 'cultivo' => true, 'produccion_dispensa' => true }) }
  let(:admin)      { create(:user, :admin, club: club) }
  let!(:sede)      { create(:sede, club: club, created_by: admin) }
  let(:cultivador) { create(:user, role: 'cultivador', club: club) }

  def alta(nombre = 'Big Bloom')
    post '/insumos', params: { insumo: { nombre: nombre, unidad_medida: 'mililitro', tipo: 'cultivo' } },
                     headers: auth_headers, as: :json
  end

  it 'nace con stock 0, sin compra y sin asiento contable' do
    sign_in_as(admin)

    expect { alta }.not_to(change { ActsAsTenant.with_tenant(club) { club.movimientos_contables.count } })

    expect(response).to have_http_status(:created)
    insumo = ActsAsTenant.with_tenant(club) { club.insumos.find(json['id']) }
    expect(insumo.stock_actual).to eq(0)
    expect(insumo.insumo_compras).to be_empty
  end

  it 'cae ya en un depósito de cultivo (la respuesta dice cuál)' do
    sign_in_as(admin)

    alta

    expect(json['deposito_id']).to be_present
    expect(json['deposito_clave']).to eq('cultivo')
  end

  it 'el cultivador, que arma las recetas, puede darlo de alta' do
    sign_in_as(cultivador)

    alta

    expect(response).to have_http_status(:created)
  end

  it 'el cultivador sigue sin poder reponer (eso mueve plata)' do
    insumo = ActsAsTenant.with_tenant(club) { club.insumos.create!(nombre: 'Base', unidad_medida: 'mililitro', tipo: 'cultivo') }
    sign_in_as(cultivador)

    post "/insumos/#{insumo.id}/comprar", params: { cantidad: 100, costo_total_ars: 5000 }, headers: auth_headers, as: :json

    expect(response).to have_http_status(:forbidden)
  end

  it 'el dispensador no puede' do
    sign_in_as(create(:user, role: 'dispensador', club: club))

    alta

    expect(response).to have_http_status(:forbidden)
  end

  # Regresión: dos `before_action :require_gestion` en el controller → valía sólo el último
  # (transferir) y reponer/ajustar/editar/borrar no pedían rol.
  it 'reponer, ajustar, editar y borrar siguen siendo de administración' do
    insumo = ActsAsTenant.with_tenant(club) { club.insumos.create!(nombre: 'Base', unidad_medida: 'mililitro', tipo: 'cultivo') }
    sign_in_as(create(:user, role: 'dispensador', club: club))

    post "/insumos/#{insumo.id}/comprar", params: { cantidad: 1, costo_total_ars: 1 }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:forbidden)
    put "/insumos/#{insumo.id}", params: { insumo: { nombre: 'X' } }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:forbidden)
    delete "/insumos/#{insumo.id}", headers: auth_headers
    expect(response).to have_http_status(:forbidden)
  end

  it 'queda en la organización de quien lo da de alta' do
    otro = create(:club, features: { 'cultivo' => true })
    sign_in_as(admin)

    alta('Sólo mío')

    expect(ActsAsTenant.with_tenant(otro) { otro.insumos.where(nombre: 'Sólo mío') }).to be_empty
  end
end
