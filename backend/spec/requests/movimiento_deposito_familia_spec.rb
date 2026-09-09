require 'rails_helper'

# LA CATEGORÍA DICE A QUÉ CLASE DE DEPÓSITO VA LA COMPRA.
#
# El formulario ofrecía los diez depósitos del club sin mirar la categoría, y nadie validaba: las
# bolsas del dispensario entraban al depósito de Cultivo de otra sede sin una queja. El comentario
# de `aplicar_deposito!` prometía ese filtro desde que se escribió. Ahora la pantalla lo DEDUCE
# (categoría × sede) y esto lo hace cumplir, porque por la API se saltea siempre.
RSpec.describe 'A qué depósito puede entrar una compra', type: :request do
  let(:club)  { create(:club, features: { 'bar' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let!(:sede) { create(:sede, club: club, created_by: admin, tipo: 'mixta') }

  before do
    ActsAsTenant.with_tenant(club) { Finanzas::SembrarDepositos.new(club).call }
    sign_in_as(admin)
  end

  def deposito(clave) = ActsAsTenant.with_tenant(club) { club.depositos.find_by(clave_sistema: clave, sede_id: sede.id) }

  def categoria(nombre, comportamiento)
    ActsAsTenant.with_tenant(club) do
      CategoriaContable.create!(club: club, nombre: nombre, tipo: 'egreso', comportamiento: comportamiento)
    end
  end

  def comprar(cat:, dep:, cantidad: 10)
    post '/api/movimientos_contables', params: {
      movimiento_contable: {
        tipo: 'egreso', categoria: 'insumo', categoria_contable_id: cat.id,
        descripcion: 'Bolsas', monto_ars: 80_000, fecha: Date.current,
        destino: { tipo: 'deposito', deposito_id: dep.id, nombre: 'Bolsas',
                   unidad_medida: 'unidad', cantidad: cantidad }
      }
    }, as: :json
  end

  it 'entra donde le corresponde' do
    cat = categoria('packaging', 'insumo_general')

    comprar(cat: cat, dep: deposito('general'))

    expect(response).to have_http_status(:created)
    expect(ActsAsTenant.with_tenant(club) { club.insumos.find_by(nombre: 'Bolsas')&.deposito_id })
      .to eq(deposito('general').id)
  end

  # El caso que Germán tenía a un click: la lista le ofrecía «Cultivo · Finca Norte» para una
  # categoría del dispensario y el backend lo aceptaba.
  it 'y no entra a un depósito de otra clase, con un mensaje que se entiende' do
    cat = categoria('packaging', 'insumo_general')

    comprar(cat: cat, dep: deposito('cultivo'))

    expect(response).to have_http_status(:unprocessable_entity)
    body = JSON.parse(response.body)['errors'].join
    expect(body).to include('packaging')
    expect(body).to include('insumos generales')   # en castellano, no 'insumo_general'
    # Ni el asiento ni el insumo quedaron sueltos.
    expect(club.movimientos_contables.count).to eq(0)
    expect(ActsAsTenant.with_tenant(club) { club.insumos.count }).to eq(0)
  end

  it 'un insumo de cultivo no entra al depósito general' do
    comprar(cat: categoria('Fertilizante', 'insumo'), dep: deposito('general'))

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['errors'].join).to include('insumos de cultivo')
  end

  # Una compra puede cargarse sin categoría del catálogo: entonces no hay contra qué comparar.
  it 'sin categoría no se valida nada' do
    post '/api/movimientos_contables', params: {
      movimiento_contable: {
        tipo: 'egreso', categoria: 'insumo', descripcion: 'Bolsas', monto_ars: 80_000,
        fecha: Date.current,
        destino: { tipo: 'deposito', deposito_id: deposito('cultivo').id, nombre: 'Bolsas',
                   unidad_medida: 'unidad', cantidad: 10 }
      }
    }, as: :json

    expect(response).to have_http_status(:created)
  end

  # Un depósito propio del club se comporta como insumos generales. Devolvía la familia 'general',
  # que no existe en ningún otro lado, así que quedaba inalcanzable apenas el destino empezó a
  # derivarse de la categoría.
  it 'un depósito propio del club recibe insumos generales' do
    propio = ActsAsTenant.with_tenant(club) do
      club.depositos.create!(nombre: 'Taller', sede_id: sede.id, activo: true)
    end
    expect(propio.familia).to eq('insumo_general')

    comprar(cat: categoria('packaging', 'insumo_general'), dep: propio)
    expect(response).to have_http_status(:created)
  end
end

# EL DEPÓSITO DE DISPENSACIÓN NO RECIBE COMPRAS: lo llena la cosecha y la manicura, y sale por
# dispensación. Comparte familia con el Salón, así que sin este guard una compra de mercadería lo
# ofrecía como destino y reventaba mucho más abajo.
RSpec.describe 'El depósito de Dispensación', type: :request do
  let(:club)  { create(:club, features: { 'bar' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let!(:sede) { create(:sede, club: club, created_by: admin, tipo: 'mixta') }

  before do
    ActsAsTenant.with_tenant(club) { Finanzas::SembrarDepositos.new(club).call }
    sign_in_as(admin)
  end

  it 'no acepta una compra, y lo dice' do
    dep = ActsAsTenant.with_tenant(club) { club.depositos.find_by(clave_sistema: 'dispensacion', sede_id: sede.id) }
    skip 'esta sede no siembra depósito de dispensación' if dep.nil?

    cat = ActsAsTenant.with_tenant(club) do
      CategoriaContable.create!(club: club, nombre: 'Bebidas', tipo: 'egreso', comportamiento: 'mercaderia')
    end

    post '/api/movimientos_contables', params: {
      movimiento_contable: {
        tipo: 'egreso', categoria: 'insumo', categoria_contable_id: cat.id,
        descripcion: 'Cerveza', monto_ars: 50_000, fecha: Date.current,
        destino: { tipo: 'deposito', deposito_id: dep.id, nombre: 'Cerveza', cantidad: 10 }
      }
    }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['errors'].join).to include('cosecha')
  end
end
