require 'rails_helper'

# La categoría contable es el ATAJO, no la puerta. Una organización que todavía no armó su
# catálogo —que es como arranca cualquiera— tiene que poder anotar lo que gastó igual.
RSpec.describe 'Movimiento sin categoría del catálogo', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  before { sign_in_as(admin) }

  it 'se registra un gasto sin categoria_contable_id' do
    expect {
      post '/movimientos_contables', headers: auth_headers, as: :json, params: {
        movimiento_contable: {
          tipo: 'egreso', categoria: 'otro', descripcion: 'Limpieza especial de salas',
          monto_ars: 45_000, fecha: Time.zone.today.to_s, medio_pago: 'efectivo', pagado: true
        }
      }
    }.to change { MovimientoContable.count }.by(1)

    expect(response).to have_http_status(:created)
    mov = MovimientoContable.last
    expect(mov.categoria_contable_id).to be_nil
    expect(mov.unidad_negocio_id).to be_nil   # sin categoría no hay sector: es del club
    expect(mov.descripcion).to eq('Limpieza especial de salas')
  end

  # El flujo aporta la clave legacy, que sí es NOT NULL. 'otro' es el último recurso: un gasto
  # y una compra no son lo mismo en el libro.
  it 'una compra sin categoría queda clasificada como insumo, no como "otro"' do
    post '/movimientos_contables', headers: auth_headers, as: :json, params: {
      movimiento_contable: {
        tipo: 'egreso', categoria: 'insumo', descripcion: 'Bolsas', monto_ars: 8_000,
        fecha: Time.zone.today.to_s, medio_pago: 'efectivo', pagado: true
      }
    }

    expect(response).to have_http_status(:created)
    expect(MovimientoContable.last.categoria).to eq('insumo')
  end

  it 'aparece en el listado y en el resumen como cualquier otro' do
    post '/movimientos_contables', headers: auth_headers, as: :json, params: {
      movimiento_contable: {
        tipo: 'egreso', categoria: 'otro', descripcion: 'Limpieza', monto_ars: 45_000,
        fecha: Time.zone.today.to_s, medio_pago: 'efectivo', pagado: true
      }
    }

    get '/movimientos_contables/dashboard', headers: auth_headers
    body = JSON.parse(response.body)

    expect(body.dig('mes_actual', 'egresos')).to eq(45_000.0)
    expect(body.dig('mes_actual', 'por_categoria').first['total']).to eq(45_000.0)
  end
end
