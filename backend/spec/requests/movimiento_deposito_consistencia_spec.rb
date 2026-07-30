require 'rails_helper'

# El depósito elegido en la compra manda: define la sede del asiento y qué puede entrar. Sin estos
# guards se podía reponer un insumo que vive en OTRO depósito → el stock subía en un depósito y el
# egreso quedaba en la sede de otro (la plata en una sede, la mercadería en la otra).
RSpec.describe 'Compra con destino a depósito — consistencia', type: :request do
  let(:club)  { create(:club, features: { 'bar' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let!(:norte) { create(:sede, club: club, created_by: admin, tipo: 'produccion') }
  let!(:sur)   { create(:sede, club: club, created_by: admin, tipo: 'produccion') }

  before do
    ActsAsTenant.with_tenant(club) { Finanzas::SembrarDepositos.new(club).call }
    sign_in_as(admin)
  end

  def deposito(clave, sede)
    ActsAsTenant.with_tenant(club) { club.depositos.find_by(clave_sistema: clave, sede_id: sede.id) }
  end

  def comprar(destino:, monto: 80_000)
    post '/api/movimientos_contables', params: {
      movimiento_contable: {
        tipo: 'egreso', categoria: 'insumo', descripcion: 'Compra de prueba',
        monto_ars: monto, fecha: Date.current, destino: destino
      }
    }, as: :json
  end

  it 'repone el insumo cuando el depósito es el suyo' do
    dep = deposito('cultivo', norte)
    insumo = ActsAsTenant.with_tenant(club) do
      club.insumos.create!(nombre: 'Fertilizante', unidad_medida: 'litro', stock_actual: 5,
                           deposito: dep, sede_id: norte.id)
    end

    comprar(destino: { tipo: 'deposito', deposito_id: dep.id, insumo_id: insumo.id, cantidad: 20 })

    expect(response).to have_http_status(:created)
    expect(insumo.reload.stock_actual.to_d).to eq(25)
    expect(JSON.parse(response.body).dig('sede', 'id')).to eq(norte.id)
  end

  it 'rechaza reponer un insumo que vive en otro depósito' do
    dep_sur = deposito('cultivo', sur)
    insumo_norte = ActsAsTenant.with_tenant(club) do
      club.insumos.create!(nombre: 'Sustrato', unidad_medida: 'bolsa', stock_actual: 3,
                           deposito: deposito('cultivo', norte), sede_id: norte.id)
    end

    comprar(destino: { tipo: 'deposito', deposito_id: dep_sur.id, insumo_id: insumo_norte.id, cantidad: 10 })

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['errors'].join).to include('Sustrato')
    expect(insumo_norte.reload.stock_actual.to_d).to eq(3)   # no se tocó el stock
    expect(club.movimientos_contables.count).to eq(0)        # ni quedó el asiento suelto
  end

  it 'un insumo nuevo nace en el depósito elegido y en su sede' do
    dep = deposito('general', sur)

    comprar(destino: { tipo: 'deposito', deposito_id: dep.id, nombre: 'Lavandina',
                       unidad_medida: 'litro', cantidad: 6 })

    expect(response).to have_http_status(:created)
    nuevo = ActsAsTenant.with_tenant(club) { club.insumos.find_by(nombre: 'Lavandina') }
    expect(nuevo.deposito_id).to eq(dep.id)
    expect(nuevo.sede_id).to eq(sur.id)
    expect(nuevo.stock_actual.to_d).to eq(6)
  end

  it 'rechaza un bar que no es de la sede del depósito Salón' do
    social = create(:sede, club: club, created_by: admin, tipo: 'social')
    otra_social = create(:sede, club: club, created_by: admin, tipo: 'social')
    ActsAsTenant.with_tenant(club) { Finanzas::SembrarDepositos.new(club).call }
    bar_otra = create(:barra, club: club, sede: otra_social)
    dep_salon = deposito('salon', social)

    comprar(destino: { tipo: 'salon', deposito_id: dep_salon.id, bar_id: bar_otra.id,
                       nombre: 'Cerveza', cantidad: 12, precio_ars: 2500 })

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['errors'].join).to include(bar_otra.nombre)
    expect(club.movimientos_contables.count).to eq(0)
  end
end
