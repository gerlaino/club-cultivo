require 'rails_helper'

# Contar UN producto sin cerrar el turno.
#
# Cerrar y reabrir sigue siendo el arqueo completo, pero con quince frascos sobre la mesa son
# veinte minutos: un control que cuesta eso no se hace dos veces por día, y el que no se hace no
# controla nada. Contar de a uno cuesta treinta segundos.
#
# A diferencia de la corrección al RECIBIR —que ajusta el reparto entre mesa y depósito, sin
# tocar el inventario— acá la diferencia sí es una pérdida real: el producto estaba sobre la mesa
# y ya no está.
RSpec.describe 'Contar un producto del mostrador', type: :request do
  include AuthHelpers

  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:ana)      { create(:user, :dispensador, club: club) }
  let(:sede)     { create(:sede, club: club, tipo: 'social') }
  let(:lote)     { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }
  let(:paciente) { ActsAsTenant.with_tenant(club) { create(:paciente, club: club) } }

  let!(:stock) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 500, estado: 'asignado', disponibilidad: 'ambas', precio_sugerido_ars: 100)
    end
  end

  let!(:turno) { abrir_mostrador!(sede, usuario: admin, recibe: ana) }
  def item = turno.items.first

  def contar!(contado, motivo: nil, como: ana)
    sign_in_as(como)
    post "/api/sedes/#{sede.id}/mostrador/contar", headers: auth_headers,
         params: { item_id: item.id, contado: contado, motivo: motivo }.compact
    JSON.parse(response.body)
  end

  it 'si cuadra, no pasa nada' do
    expect { contar!(item.esperado) }
      .not_to change { stock.reload.cantidad }
    expect(response).to have_http_status(:ok)
  end

  it 'un faltante ajusta el inventario, como el cierre' do
    esperado = item.esperado
    contar!(esperado - 3, motivo: 'se cayó al piso')

    expect(response).to have_http_status(:ok)
    expect(stock.reload.cantidad.to_f).to eq(497.0)
    mov = stock.stock_movimientos.where(tipo: 'ajuste').last
    expect(mov.gramos.to_f).to eq(-3.0)
    expect(mov.notas).to match(/Conteo del mostrador — faltante de 3\.0 g — se cayó al piso/)
    expect(mov.turno_mostrador_id).to eq(turno.id)
  end

  # Lo importante: el esperado del CIERRE se corre con el conteo, o a la noche se cuenta dos
  # veces la misma diferencia.
  it 'y el cierre de la noche ya no la vuelve a encontrar' do
    esperado = item.esperado
    contar!(esperado - 3, motivo: 'se cayó al piso')

    expect(item.reload.esperado).to eq(esperado - 3)

    sign_in_as(ana)
    post "/api/sedes/#{sede.id}/mostrador/cerrar", headers: auth_headers,
         params: { conteos: [{ item_id: item.id, contado: (esperado - 3).to_f }],
                   efectivo_contado_ars: 0 }

    expect(response).to have_http_status(:ok)
    expect(item.reload.diferencia_cierre.to_f).to eq(0.0)
  end

  it 'un sobrante también' do
    contar!(item.esperado + 2, motivo: 'apareció')

    expect(stock.reload.cantidad.to_f).to eq(502.0)
  end

  it 'con diferencia y sin motivo no se registra' do
    body = contar!(item.esperado - 3)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(body['error']).to match(/escribí el motivo/i)
    expect(stock.reload.cantidad.to_f).to eq(500.0)
  end

  it 'queda quién contó y cuándo' do
    contar!(item.esperado - 1, motivo: 'merma')

    mov = TurnoMostradorMovimiento.unscoped.conteos.last
    expect(mov.usuario_id).to eq(ana.id)
    expect(mov.cantidad.to_f).to eq(-1.0)
    expect(mov.notas).to eq('merma')
  end

  it 'no se cuenta un producto que no está en el turno' do
    sign_in_as(ana)
    post "/api/sedes/#{sede.id}/mostrador/contar", headers: auth_headers,
         params: { item_id: 999_999, contado: 10 }

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'con el mostrador cerrado no se cuenta nada' do
    ActsAsTenant.with_tenant(club) do
      Mostradores::CerrarTurno.call(turno: turno, usuario: ana, efectivo_contado_ars: 0,
                                    conteos: [{ item_id: item.id, contado: item.esperado }])
    end

    body = contar!(10, motivo: 'x')
    expect(response).to have_http_status(:unprocessable_entity)
    expect(body['error']).to match(/cerrado/i)
  end
end
