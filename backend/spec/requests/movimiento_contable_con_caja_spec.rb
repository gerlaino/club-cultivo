require 'rails_helper'

# DE QUÉ CAJA SALE EL EFECTIVO, Y A CUÁL ENTRA (sep-2026, pedido de Germán).
#
# Un gasto pagado en efectivo con la plata del cajón no tenía forma correcta de registrarse: o se
# cargaba en Contabilidad y el arqueo de la noche daba faltante, o se cargaba además como «salida
# de caja» desde el mostrador y el gasto quedaba asentado dos veces. Ahora, al cargar un movimiento
# en efectivo se elige de qué caja abierta sale (o a cuál entra, si es un ingreso), y el arqueo lo
# espera. Sin elegir, el asiento se escribe igual y no toca ningún arqueo — la misma regla que al
# dispensar del depósito.
RSpec.describe 'Un movimiento contable en efectivo atado a una caja', type: :request do
  let(:club)        { create(:club) }
  let(:admin)       { create(:user, :admin, club: club) }
  let(:dispensador) { create(:user, :dispensador, club: club) }
  let(:sede)        { create(:sede, club: club, created_by: admin, tipo: 'mixta') }
  let(:caja) do
    ActsAsTenant.with_tenant(club) do
      Mostradores::AbrirCaja.call(mostrador: sede.mostrador!, usuario: dispensador, efectivo_contado_ars: 20_000)
      sede.mostrador!.turno_abierto.caja_turno
    end
  end

  before { sign_in_as(admin) }

  def crear(attrs)
    post '/api/movimientos_contables', params: { movimiento_contable: {
      sede_id: sede.id, descripcion: 'Flete', monto_ars: 3_000, fecha: Time.zone.today,
      categoria: 'otro', pagado: true, medio_pago: 'efectivo',
    }.merge(attrs) }, as: :json
  end

  it 'un gasto en efectivo de la caja baja lo esperado en el arqueo' do
    esperado = caja.efectivo_esperado_ars

    crear(tipo: 'egreso', caja_turno_id: caja.id)

    expect(response).to have_http_status(:created), response.body
    expect(caja.reload.efectivo_esperado_ars).to eq(esperado - 3_000)
    expect(MovimientoContable.last.fecha_pago).to eq(Time.zone.today)
  end

  it 'un ingreso excepcional en efectivo a la caja sube lo esperado' do
    esperado = caja.efectivo_esperado_ars

    crear(tipo: 'ingreso', categoria: 'subvencion', descripcion: 'Donación', caja_turno_id: caja.id)

    expect(response).to have_http_status(:created), response.body
    expect(caja.reload.efectivo_esperado_ars).to eq(esperado + 3_000)
  end

  it 'sin caja, el asiento entra al libro y no toca ningún arqueo' do
    esperado = caja.efectivo_esperado_ars

    crear(tipo: 'egreso')

    expect(response).to have_http_status(:created), response.body
    expect(caja.reload.efectivo_esperado_ars).to eq(esperado)
  end

  it 'un gasto pendiente no sale de ninguna caja todavía' do
    crear(tipo: 'egreso', pagado: false, caja_turno_id: caja.id)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['error']).to match(/sólo aplica a un pago en efectivo/)
  end

  # La diferencia del arqueo también es un egreso en efectivo atado a la caja, y NO es plata que
  # salió durante el turno: contarla como salida movería lo esperado con lo que se midió contra lo
  # esperado, y un cierre con faltante cambiaría su propia diferencia.
  it 'el faltante del arqueo no cuenta como salida' do
    esperado = caja.efectivo_esperado_ars
    ActsAsTenant.with_tenant(club) do
      res = Mostradores::CerrarCaja.call(turno: sede.mostrador!.turno_abierto, usuario: dispensador,
                                         conteos: [], efectivo_contado_ars: esperado - 5_000)
      expect(res.ok?).to be(true), res.error.to_s
    end
    caja.reload

    expect(caja.movimientos_contables.where(categoria: 'diferencia_caja', tipo: 'egreso')).to exist
    expect(caja.total_salidas_ars).to eq(0.0)
    expect(caja.efectivo_esperado_ars).to eq(esperado)
    expect(caja.diferencia_ars).to eq(-5_000.0)
  end
end
