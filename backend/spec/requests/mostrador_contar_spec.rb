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

  # Lo que hay sobre la mesa de este producto, ahora.
  def en_la_mesa = mesa_de(sede)[stock.id].to_d

  def contar!(contado, motivo: nil, como: ana)
    sign_in_as(como)
    post "/api/sedes/#{sede.id}/mostrador/contar", headers: auth_headers,
         params: { stock_id: stock.id, contado: contado, motivo: motivo }.compact
    JSON.parse(response.body)
  end

  it 'si cuadra, no pasa nada' do
    expect { contar!(en_la_mesa) }
      .not_to change { stock.reload.cantidad }
    expect(response).to have_http_status(:ok)
  end

  it 'un faltante ajusta el inventario, como el cierre' do
    contar!(en_la_mesa - 3, motivo: 'se cayó al piso')

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
    esperado = en_la_mesa
    contar!(esperado - 3, motivo: 'se cayó al piso')

    expect(en_la_mesa).to eq(esperado - 3)

    sign_in_as(ana)
    post "/api/sedes/#{sede.id}/mostrador/cerrar", headers: auth_headers,
         params: { conteos: [{ stock_id: stock.id, contado: (esperado - 3).to_f }],
                   efectivo_contado_ars: 0 }

    expect(response).to have_http_status(:ok)
    item = turno.reload.items.find_by(stock_id: stock.id)
    expect(item.cantidad_cierre.to_d - item.esperado_cierre.to_d).to eq(0)
  end

  it 'con diferencia y sin motivo no se registra' do
    body = contar!(en_la_mesa - 3)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(body['error']).to match(/escribí el motivo/i)
    expect(stock.reload.cantidad.to_f).to eq(500.0)
  end

  it 'queda quién contó y cuándo' do
    contar!(en_la_mesa - 1, motivo: 'merma')

    mov = MostradorMovimiento.unscoped.recientes.first
    expect(mov.tipo).to eq('ajuste')
    expect(mov.usuario_id).to eq(ana.id)
    expect(mov.cantidad.to_f).to eq(-1.0)
    expect(mov.motivo).to match(/merma/)
  end

  it 'no se cuenta un producto que no está sobre la mesa' do
    sign_in_as(ana)
    post "/api/sedes/#{sede.id}/mostrador/contar", headers: auth_headers,
         params: { stock_id: 999_999, contado: 10 }

    expect(response).to have_http_status(:unprocessable_entity)
  end

  # Contar sigue teniendo sentido con la caja cerrada: el producto está sobre la mesa igual, y
  # administración puede querer verificarlo antes de que llegue nadie.
  it 'se puede contar también con la caja cerrada' do
    ActsAsTenant.with_tenant(club) do
      Mostradores::CerrarCaja.call(turno: turno, usuario: ana, efectivo_contado_ars: 0,
                                   conteos: [{ stock_id: stock.id, contado: en_la_mesa }])
    end

    contar!(en_la_mesa - 1, motivo: 'se cayó', como: admin)
    expect(response).to have_http_status(:ok)
  end

  # CONTAR NO PUEDE CREAR PRODUCTO DE LA NADA.
  #
  # `ajustar_inventario!` con diferencia positiva SUMA al stock del club: contando 997 donde había
  # 100 entraban 897 g trazables que nadie cargó. Es una puerta de entrada de producto sin origen,
  # y se dispara con un dedazo. Quien atiende no puede justificar un sobrante —él no elige qué hay
  # sobre la mesa, la carga administración— y acá rechazar es seguro: no bloquea nada.
  describe 'contar de MÁS' do
    it 'quien atiende no puede: el inventario no se toca y se le dice a quién pedirle' do
      antes_mesa  = en_la_mesa
      antes_stock = stock.reload.cantidad.to_d

      body = contar!(antes_mesa + 100, motivo: 'aparecieron', como: ana)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/más de lo que hay/i)
      expect(body['error']).to match(/administración/i)
      expect(en_la_mesa).to eq(antes_mesa)
      expect(stock.reload.cantidad.to_d).to eq(antes_stock)
    end

    it 'administración sí: ella gobierna la mesa, y el inventario sube con ella' do
      antes = en_la_mesa

      contar!(antes + 10, motivo: 'apareció un frasco', como: admin)

      expect(response).to have_http_status(:ok)
      expect(en_la_mesa).to eq(antes + 10)
      expect(stock.reload.cantidad.to_f).to eq(510.0)
      expect(stock.stock_movimientos.where(tipo: 'ajuste').last.gramos.to_f).to eq(10.0)
    end

    it 'y el faltante de quien atiende se sigue aplicando: restar no inventa nada' do
      antes = en_la_mesa

      contar!(antes - 10, motivo: 'se fraccionó', como: ana)

      expect(response).to have_http_status(:ok)
      expect(en_la_mesa).to eq(antes - 10)
    end
  end
end