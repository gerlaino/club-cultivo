require 'rails_helper'

# Se podía MARCAR una compra como pendiente de pago, pero no había ninguna forma de decir
# después que se pagó: el gasto quedaba pendiente para siempre y el total por pagar del club
# no bajaba nunca.
#
# No genera un movimiento nuevo: el egreso ya está asentado desde que se compró. Lo que cambia
# es su estado de pago — y con eso sale del "a crédito".
#
# Y desde sep-2026 el pago dice CÓMO, CUÁNDO y DE DÓNDE: medio obligatorio, `fecha_pago` (la
# `fecha` del gasto no se mueve) y, en efectivo, de qué caja abierta salió la plata, para que el
# arqueo de esa noche lo espere en vez de dar faltante.
RSpec.describe 'Registrar el pago de un movimiento pendiente', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin, tipo: 'mixta') }

  def movimiento(pagado:, tipo: 'egreso', fecha: Time.zone.today)
    club.movimientos_contables.create!(
      sede: sede, created_by: admin, tipo: tipo, categoria: 'insumo',
      descripcion: 'Compra de fertilizante', monto_ars: 15_000,
      fecha: fecha, pagado: pagado, medio_pago: 'efectivo',
    )
  end

  before { sign_in_as(admin) }

  it 'marca el gasto como pagado, con qué y cuándo' do
    mov = movimiento(pagado: false, fecha: Time.zone.today - 20)

    patch "/api/movimientos_contables/#{mov.id}/registrar_pago",
          params: { medio_pago: 'transferencia', fecha_pago: Time.zone.today - 2 }, as: :json

    expect(response).to have_http_status(:ok), response.body
    mov.reload
    expect(mov.pagado).to be(true)
    expect(mov.medio_pago).to eq('transferencia')
    expect(mov.fecha_pago).to eq(Time.zone.today - 2)
    # La fecha del GASTO no se mueve: el egreso se reconoce cuando se compró.
    expect(mov.fecha).to eq(Time.zone.today - 20)
    expect(JSON.parse(response.body)['fecha_pago']).to eq((Time.zone.today - 2).to_s)
  end

  it 'sin fecha, se pagó hoy' do
    mov = movimiento(pagado: false, fecha: Time.zone.today - 5)

    patch "/api/movimientos_contables/#{mov.id}/registrar_pago", params: { medio_pago: 'efectivo' }, as: :json

    expect(mov.reload.fecha_pago).to eq(Time.zone.today)
  end

  it 'exige decir cómo se pagó' do
    mov = movimiento(pagado: false)

    patch "/api/movimientos_contables/#{mov.id}/registrar_pago", as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['error']).to match(/cómo se pagó/i)
    expect(mov.reload.pagado).to be(false)
  end

  it 'no se paga antes de comprar ni en el futuro' do
    mov = movimiento(pagado: false, fecha: Time.zone.today - 5)

    patch "/api/movimientos_contables/#{mov.id}/registrar_pago",
          params: { medio_pago: 'efectivo', fecha_pago: Time.zone.today - 9 }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['errors'].join).to match(/anterior a la fecha del gasto/)

    patch "/api/movimientos_contables/#{mov.id}/registrar_pago",
          params: { medio_pago: 'efectivo', fecha_pago: Time.zone.today + 1 }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(mov.reload.pagado).to be(false)
  end

  context 'en efectivo, de una caja' do
    let(:dispensador) { create(:user, :dispensador, club: club) }
    let(:caja) do
      ActsAsTenant.with_tenant(club) do
        Mostradores::AbrirCaja.call(mostrador: sede.mostrador!, usuario: dispensador, efectivo_contado_ars: 10_000)
        sede.mostrador!.turno_abierto.caja_turno
      end
    end

    it 'queda atado a la caja y el arqueo lo descuenta' do
      mov      = movimiento(pagado: false)
      esperado = caja.efectivo_esperado_ars

      patch "/api/movimientos_contables/#{mov.id}/registrar_pago",
            params: { medio_pago: 'efectivo', caja_turno_id: caja.id }, as: :json

      expect(response).to have_http_status(:ok), response.body
      expect(mov.reload.caja_turno_id).to eq(caja.id)
      expect(caja.reload.efectivo_esperado_ars).to eq(esperado - 15_000)
      expect(JSON.parse(response.body).dig('caja', 'sede')).to eq(sede.nombre)
    end

    it 'sin elegir caja, el asiento queda igual y no entra a ningún arqueo' do
      mov      = movimiento(pagado: false)
      esperado = caja.efectivo_esperado_ars

      patch "/api/movimientos_contables/#{mov.id}/registrar_pago", params: { medio_pago: 'efectivo' }, as: :json

      expect(mov.reload.pagado).to be(true)
      expect(mov.caja_turno_id).to be_nil
      expect(caja.reload.efectivo_esperado_ars).to eq(esperado)
    end

    it 'rechaza una caja cerrada' do
      mov      = movimiento(pagado: false)
      esperado = caja.efectivo_esperado_ars
      ActsAsTenant.with_tenant(club) do
        res = Mostradores::CerrarCaja.call(turno: sede.mostrador!.turno_abierto, usuario: dispensador,
                                           conteos: [], efectivo_contado_ars: esperado)
        expect(res.ok?).to be(true), res.error.to_s
      end
      expect(caja.reload.cerrada?).to be(true)

      patch "/api/movimientos_contables/#{mov.id}/registrar_pago",
            params: { medio_pago: 'efectivo', caja_turno_id: caja.id }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/no está abierta/)
      expect(mov.reload.pagado).to be(false)
    end

    it 'rechaza la caja de otra organización' do
      mov  = movimiento(pagado: false)
      otro = create(:club)
      otra_sede = create(:sede, club: otro, tipo: 'mixta')
      otra_caja = ActsAsTenant.with_tenant(otro) do
        Mostradores::AbrirCaja.call(mostrador: otra_sede.mostrador!, usuario: create(:user, :admin, club: otro),
                                    efectivo_contado_ars: 0)
        otra_sede.mostrador!.turno_abierto.caja_turno
      end

      patch "/api/movimientos_contables/#{mov.id}/registrar_pago",
            params: { medio_pago: 'efectivo', caja_turno_id: otra_caja.id }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(mov.reload.caja_turno_id).to be_nil
    end

    it 'una transferencia no sale de ninguna caja' do
      mov = movimiento(pagado: false)

      patch "/api/movimientos_contables/#{mov.id}/registrar_pago",
            params: { medio_pago: 'transferencia', caja_turno_id: caja.id }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/sólo aplica a un pago en efectivo/)
    end
  end

  it 'una cuota se puede pagar antes de vencer' do
    compra = ActsAsTenant.with_tenant(club) do
      club.compras_cuotas.create!(sede: sede, created_by: admin, descripcion: 'Aire', categoria: 'mantenimiento',
                                  monto_total_ars: 60_000, cuotas_total: 3, fecha_primera_cuota: Time.zone.today)
    end
    cuota_futura = compra.movimientos_contables.order(:fecha).last
    expect(cuota_futura.fecha).to be > Time.zone.today

    patch "/api/movimientos_contables/#{cuota_futura.id}/registrar_pago", params: { medio_pago: 'mercado_pago' }, as: :json

    expect(response).to have_http_status(:ok), response.body
    expect(cuota_futura.reload.fecha_pago).to eq(Time.zone.today)
  end

  # El egreso ya estaba en el libro desde la compra: pagarlo no lo duplica.
  it 'NO crea un movimiento nuevo' do
    mov = movimiento(pagado: false)

    expect {
      patch "/api/movimientos_contables/#{mov.id}/registrar_pago", params: { medio_pago: 'efectivo' }, as: :json
    }.not_to change(MovimientoContable, :count)
  end

  it 'el monto no se toca' do
    mov = movimiento(pagado: false)

    patch "/api/movimientos_contables/#{mov.id}/registrar_pago", params: { medio_pago: 'efectivo' }, as: :json

    expect(mov.reload.monto_ars.to_f).to eq(15_000.0)
  end

  it 'rechaza pagar algo que ya estaba pagado' do
    mov = movimiento(pagado: true)

    patch "/api/movimientos_contables/#{mov.id}/registrar_pago", params: { medio_pago: 'efectivo' }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['error']).to match(/ya figura como pagado/i)
  end

  it 'no toca un período cerrado' do
    mov = movimiento(pagado: false, fecha: Time.zone.today - 40)
    club.update!(contabilidad_cerrada_hasta: Time.zone.today - 10)

    patch "/api/movimientos_contables/#{mov.id}/registrar_pago", params: { medio_pago: 'efectivo' }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(mov.reload.pagado).to be(false)
  end

  it 'un rol sin permiso de escritura no puede' do
    mov = movimiento(pagado: false)
    dispensador = create(:user, :dispensador, club: club)
    sign_in_as(dispensador)

    patch "/api/movimientos_contables/#{mov.id}/registrar_pago", params: { medio_pago: 'efectivo' }, as: :json

    expect(response).to have_http_status(:forbidden)
    expect(mov.reload.pagado).to be(false)
  end
end
