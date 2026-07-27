require 'rails_helper'

# Nuevo Movimiento → entrada de stock. Camino unificado (jul 2026): el depósito lo elige el usuario
# (entre los del área de la categoría) en vez de derivarlo del viejo "comportamiento".
RSpec.describe 'Movimiento contable con destino a depósito', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  before { sign_in_as(admin) }

  # área Cultivo + su depósito + una categoría de esa área
  let(:area)     { ActsAsTenant.with_tenant(club) { club.unidades_negocio.create!(nombre: 'Cultivo', tipo: 'cultivo') } }
  let(:deposito) { ActsAsTenant.with_tenant(club) { club.depositos.create!(nombre: 'Depósito Cultivo', unidad_negocio: area, clave_sistema: 'cultivo', es_sistema: true) } }
  let(:categoria) { ActsAsTenant.with_tenant(club) { club.categorias_contables.create!(nombre: 'Fertilizantes', tipo: 'egreso', unidad_negocio: area) } }

  def crear_movimiento(destino:)
    post '/movimientos_contables',
         params: { movimiento_contable: {
           tipo: 'egreso', categoria_contable_id: categoria.id, descripcion: 'Compra fert',
           monto_ars: 10_000, fecha: Date.current.to_s, destino: destino,
         } },
         headers: auth_headers, as: :json
  end

  it 'crea un insumo nuevo en el depósito elegido y le sube el stock' do
    deposito
    expect {
      crear_movimiento(destino: { tipo: 'deposito', deposito_id: deposito.id,
                                  nombre: 'Base A', unidad_medida: 'litro', cantidad: 20 })
    }.to change { club.insumos.count }.by(1)

    expect(response).to have_http_status(:created)
    insumo = club.insumos.find_by(nombre: 'Base A')
    expect(insumo.deposito_id).to eq(deposito.id)
    expect(insumo.stock_actual).to eq(20)
    # el egreso NO genera un segundo asiento: la compra queda ligada a este movimiento
    mov = club.movimientos_contables.find_by(descripcion: 'Compra fert')
    expect(InsumoCompra.find_by(movimiento_contable_id: mov.id)).to be_present
  end

  it 'el asiento queda en la SEDE del depósito, aunque el form mande otra' do
    sede_a = ActsAsTenant.with_tenant(club) { create(:sede, club: club, created_by: admin, tipo: 'produccion') }
    sede_b = ActsAsTenant.with_tenant(club) { create(:sede, club: club, created_by: admin, tipo: 'produccion') }
    dep_a  = ActsAsTenant.with_tenant(club) do
      club.depositos.create!(nombre: 'Cultivo A', unidad_negocio: area, clave_sistema: 'cultivo', sede: sede_a, es_sistema: true)
    end

    post '/movimientos_contables', params: { movimiento_contable: {
      tipo: 'egreso', categoria_contable_id: categoria.id, descripcion: 'Fert A',
      monto_ars: 5_000, fecha: Date.current.to_s,
      sede_id: sede_b.id, # el form manda la sede equivocada
      destino: { tipo: 'deposito', deposito_id: dep_a.id, nombre: 'Base X', unidad_medida: 'litro', cantidad: 5 },
    } }, headers: auth_headers, as: :json

    expect(response).to have_http_status(:created)
    mov = club.movimientos_contables.find_by(descripcion: 'Fert A')
    expect(mov.sede_id).to eq(sede_a.id) # forzado a la sede del depósito, no la del form
    expect(club.insumos.find_by(nombre: 'Base X').sede_id).to eq(sede_a.id)
  end

  it 'sin destino (solo gasto) no crea ningún insumo' do
    deposito
    expect {
      crear_movimiento(destino: nil)
    }.not_to change { club.insumos.count }
    expect(response).to have_http_status(:created)
  end
end

# Camino Salón: la compra de mercadería del bar desde Nuevo Movimiento debe recalcular el costo
# promedio del BarProducto (antes solo bumpeaba stock → margen sin costo) y NO duplicar el egreso.
RSpec.describe 'Movimiento contable con destino al salón', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin, tipo: 'mixta') }
  let(:bar)   { ActsAsTenant.with_tenant(club) { club.bares.create!(sede: sede, nombre: 'La Terraza') } }
  let(:cat)   { ActsAsTenant.with_tenant(club) { club.categorias_contables.create!(nombre: 'Mercadería bar', tipo: 'egreso') } }

  before { sign_in_as(admin) }

  it 'crea el producto del bar con costo promedio y no duplica el egreso' do
    bar
    expect {
      post '/movimientos_contables', params: { movimiento_contable: {
        tipo: 'egreso', categoria_contable_id: cat.id, descripcion: 'Compra Coca', monto_ars: 12_000, fecha: Date.current.to_s,
        destino: { tipo: 'salon', bar_id: bar.id, nombre: 'Coca Cola', categoria: 'bebida', precio_ars: 1_200, cantidad: 100 },
      } }, headers: auth_headers, as: :json
    }.to change { bar.bar_productos.count }.by(1)

    expect(response).to have_http_status(:created)
    prod = bar.bar_productos.find_by(nombre: 'Coca Cola')
    expect(prod.stock).to eq(100)
    expect(prod.costo_ars).to eq(120) # 12.000 / 100 → recalculado
    expect(club.movimientos_contables.where(tipo: 'egreso').count).to eq(1) # sin duplicar
  end
end
