require 'rails_helper'

# AC (Germán, 13-oct-2026): en Dispensaciones, «A cuenta corriente $521.500» y el chip «Cta. cte.:
# 6 ($558.000)» no coincidían. «Ahí tiene que verse reflejada la deuda real de los pacientes para
# con la organización: ¿cuánta plata hay en cuenta corriente? Tanta, listo.»
# Regla: mismo nombre, mismo número, y una sola cuenta (`Dispensaciones::Resumen`).
RSpec.describe 'Historial de dispensaciones: el resumen', type: :request do
  include AuthHelpers

  let(:club)  { create(:club, features: { 'produccion_dispensa' => true, 'delivery' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'mixta') }
  let(:lote)  { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }
  let(:stock) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 1_000, estado: 'asignado', disponibilidad: 'ambas', precio_sugerido_ars: 100)
    end
  end
  let(:hoy) { Time.zone.today }

  around { |ej| ActsAsTenant.with_tenant(club) { ej.run } }

  def dispensa(total, cobros = {}, **attrs)
    d = Dispensacion.create!(paciente: create(:paciente, club: club), user: admin, stock: stock, sede: sede,
                             cantidad: 10, medio_pago: attrs.delete(:medio) || 'efectivo', aporte_socio_ars: total,
                             fecha_dispensacion: hoy, **attrs)
    d.cobros.destroy_all # lo que haya creado sola, se reemplaza por los cobros del caso
    cobros.each { |medio, monto| Cobro.create!(dispensacion: d, club: club, created_by: admin, medio: medio.to_s, monto_ars: monto, contexto: 'creacion') }
    d
  end

  def resumen
    get '/dispensaciones', params: { desde: hoy.iso8601, hasta: hoy.iso8601, resumen: 'true' }
    expect(response).to have_http_status(:ok), response.body
    response.parsed_body['resumen']
  end

  def chip(r, medio) = r['por_medio'].find { |c| c['medio'] == medio }

  before { sign_in_as(admin) }

  it 'la tarjeta y el chip de cuenta corriente son el MISMO número: lo que quedó debiendo' do
    # El caso de Germán: dispensas «a cuenta corriente» pagadas en parte.
    dispensa(100_000, { cuenta_corriente: 80_000, efectivo: 20_000 }, medio: 'cuenta_corriente')
    dispensa(50_000,  { cuenta_corriente: 33_500, transferencia: 16_500 }, medio: 'cuenta_corriente')
    dispensa(40_000,  { transferencia: 40_000 }, medio: 'transferencia')

    r = resumen
    expect(r['cuenta_corriente_ars']).to eq(113_500.0)
    expect(chip(r, 'cuenta_corriente')['monto_ars']).to eq(113_500.0)
    expect(chip(r, 'cuenta_corriente')['dispensas']).to eq(2)
    # Lo cobrado en el momento está en «Cobrado» y en su chip, no en el de cuenta corriente.
    expect(r['cobrado_ars']).to eq(76_500.0)
    expect(chip(r, 'efectivo')['monto_ars'] + chip(r, 'transferencia')['monto_ars']).to eq(r['cobrado_ars'])
  end

  it 'cada peso está en un solo lugar: cobrado + a favor + cuenta corriente + pendiente = total' do
    dispensa(100_000, { efectivo: 30_000, saldo_a_favor: 20_000, cuenta_corriente: 50_000 }, medio: 'mixto')
    dispensa(60_000, {}, medio: 'efectivo', cobrar_en_entrega: true, con_envio: true,
                         direccion_envio: 'Falsa 123', contacto_nombre: 'X')

    r = resumen
    total = r['cobrado_ars'] + r['saldo_a_favor_ars'] + r['cuenta_corriente_ars'] + r['pendiente_ars']
    expect(total).to eq(160_000.0)
    expect(r['saldo_a_favor_ars']).to eq(20_000.0) # no es plata que entró hoy: va aparte
    expect(r['pendiente_ars']).to eq(60_000.0)     # contra entrega sin cobrar todavía
    expect(r['por_medio'].map { |c| c['medio'] }).not_to include('mixto')
  end

  it 'una anulada no suma; una anulada con cambio sí (su plata quedó)' do
    anulada = dispensa(70_000, { efectivo: 70_000 })
    anulada.update_columns(estado_envio: 'cancelada', resolucion_anulacion: nil)
    con_cambio = dispensa(30_000, { efectivo: 30_000 })
    con_cambio.update_columns(estado_envio: 'cancelada', resolucion_anulacion: 'cambio')

    r = resumen
    expect(r['cobrado_ars']).to eq(30_000.0)
    expect(r['dispensas']).to eq(0) # ninguna vigente
  end

  it 'una dispensa vieja, sin cobros por línea, igual cuenta (su deuda y su medio)' do
    vieja = dispensa(90_000, {}, medio: 'efectivo')
    vieja.update_columns(monto_credito_ars: 40_000)

    r = resumen
    expect(r['cuenta_corriente_ars']).to eq(40_000.0)
    expect(r['cobrado_ars']).to eq(50_000.0)
    expect(r['pendiente_ars']).to eq(0.0)
  end

  it 'la deuda REAL de los pacientes hoy es la misma que la del panel de inicio' do
    p1 = create(:paciente, club: club)
    p1.cuenta_corriente!.tap { |cc| cc.update!(saldo_disponible: -25_000) }
    p2 = create(:paciente, club: club)
    p2.cuenta_corriente!.tap { |cc| cc.update!(saldo_disponible: -10_000) }
    dispensa(1_000, { efectivo: 1_000 })

    r = resumen
    panel = Panel::Conduccion.new(club: club).call
    expect(r['deuda_total_ars']).to eq(35_000.0)
    expect(r['deuda_total_ars']).to eq(panel[:finanzas][:cuentas_por_cobrar_ars])
    expect(r['deudores']).to eq(2)
  end

  it 'el dispensador ve lo de las dispensas, no la deuda de toda la organización' do
    dispensa(1_000, { efectivo: 1_000 })
    sign_in_as(create(:user, :dispensador, club: club))
    r = resumen
    expect(r).to include('cobrado_ars')
    expect(r).not_to have_key('deuda_total_ars')
  end

  it 'aislamiento: la deuda y las dispensas de otra organización no entran' do
    otra = create(:club, features: { 'produccion_dispensa' => true })
    ActsAsTenant.with_tenant(otra) do
      create(:paciente, club: otra).cuenta_corriente!.tap { |cc| cc.update!(saldo_disponible: -99_000) }
    end
    dispensa(1_000, { cuenta_corriente: 1_000 }, medio: 'cuenta_corriente')

    r = resumen
    expect(r['deuda_total_ars']).to eq(0.0)
    expect(r['cuenta_corriente_ars']).to eq(1_000.0)
  end
end
