require 'rails_helper'

# AC (Germán): "viene un admin y le dice al dispensador, dame $100.000 de la caja, anotámelos a
# mí, no como gasto, sino como retiro".
#
# Son dos hechos distintos y la diferencia es contable, no cosmética:
#
#   GASTO  — el club gastó esa plata: un flete, una compra. Baja el resultado.
#   RETIRO — la plata salió del cajón pero sigue siendo del club, o quedó a nombre de alguien.
#            Nadie gastó nada: asentarlo como egreso infla los gastos y baja el resultado por
#            plata que el club todavía tiene.
#
# Las dos restan del arqueo, porque en las dos la plata no está en el cajón.
RSpec.describe 'Retiro de caja vs. gasto pagado con la caja', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:ana)   { create(:user, :dispensador, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'social') }

  let(:caja) do
    sign_in_as(admin)
    # La caja del dispensario se abre desde el MOSTRADOR, que en el mismo gesto cuenta la
    # mercadería: abrir declarando sólo un fondo salteaba la mitad del arqueo.
    # Si ya hay una caja abierta en este mostrador se reusa: dos cajas activas sobre el mismo
    # cajón partirían el arqueo en dos por la misma plata.
    turno = ActsAsTenant.with_tenant(club) do
      sede.mostrador!.turno_abierto ||
        Mostradores::AbrirCaja.call(mostrador: sede.mostrador!, usuario: admin,
                                    efectivo_contado_ars: 200_000).turno
    end
    { 'id' => turno.caja_turno_id }
  end

  def sacar!(clase:, monto: 100_000, motivo: 'se lo llevó el admin', como: admin)
    caja # el `let` es lazy y adentro loguea al admin: si se evalúa DESPUÉS del sign_in de abajo,
         # pisa la sesión y el test termina probando al admin creyendo que prueba al dispensador.
    sign_in_as(como)
    post "/api/sedes/#{sede.id}/caja/#{caja['id']}/salida",
         headers: auth_headers, params: { monto_ars: monto, motivo: motivo, clase: clase }
    JSON.parse(response.body)
  end

  def movs = ActsAsTenant.with_tenant(club) { MovimientoContable.where(club_id: club.id) }

  describe 'un RETIRO' do
    it 'no cuenta como gasto: el resultado no se mueve' do
      sacar!(clase: 'retiro')

      expect(response).to have_http_status(:ok)
      expect(movs.egresos.sum(:monto_ars)).to eq(0)
      expect(movs.ingresos.sum(:monto_ars)).to eq(0)
    end

    it 'igual queda registrado, con monto, motivo y quién lo hizo' do
      sacar!(clase: 'retiro', motivo: 'anotámelos a mí')

      mov = movs.where(categoria: 'retiro_caja').last
      expect(mov).to be_present
      expect(mov.tipo).to eq('ajuste')
      expect(mov.monto_ars).to eq(100_000)
      expect(mov.descripcion).to include('anotámelos a mí')
      expect(mov.created_by_id).to eq(admin.id)
    end

    # Lo importante del arqueo: la plata no está en el cajón, así que el turno no la espera.
    it 'baja lo esperado en la caja' do
      cuerpo = sacar!(clase: 'retiro')

      expect(cuerpo['total_salidas_ars']).to eq(100_000.0)
      expect(cuerpo['efectivo_esperado_ars']).to eq(100_000.0) # 200.000 de fondo − 100.000
    end
  end

  describe 'un GASTO pagado con la caja' do
    it 'sí baja el resultado: el club gastó esa plata' do
      sacar!(clase: 'gasto', monto: 30_000, motivo: 'flete')

      expect(movs.egresos.sum(:monto_ars)).to eq(30_000)
    end

    it 'también baja lo esperado' do
      cuerpo = sacar!(clase: 'gasto', monto: 30_000, motivo: 'flete')

      expect(cuerpo['efectivo_esperado_ars']).to eq(170_000.0)
    end
  end

  # El caso completo que planteó Germán: el admin y el dispensador cobran en el mismo mostrador,
  # y después el admin se lleva plata. El arqueo tiene que cerrar sin faltante inventado.
  it 'con los dos cobrando en el mismo mostrador, el arqueo cierra' do
    stock = ActsAsTenant.with_tenant(club) do
      lote = create(:lote, club: club, sala: create(:sala, club: club, sede: sede))
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca',
                     cantidad: 500, precio_sugerido_ars: 100)
    end
    # `abrir_mostrador!` abre la caja y carga la mesa en un solo gesto: pedir `caja` además
    # intentaría abrir una segunda sobre el mismo cajón.
    abrir_mostrador!(sede, usuario: admin, fondo: 200_000)

    ActsAsTenant.with_tenant(club) do
      [admin, ana].each do |quien|
        d = Dispensacion.create!(paciente: create(:paciente, club: club), user: quien, stock: stock,
                                 sede: sede, cantidad: 5, medio_pago: 'efectivo',
                                 aporte_socio_ars: 20_000, fecha_dispensacion: Time.zone.today)
        Dispensaciones::RegistrarCobro.call(dispensacion: d, club: club, usuario: quien,
                                            medio: 'efectivo', monto: 20_000)
      end
    end

    cuerpo = sacar!(clase: 'retiro', monto: 100_000)

    # 200.000 de fondo + 40.000 cobrado entre los dos − 100.000 que se llevó el admin.
    expect(cuerpo['total_efectivo_ars']).to eq(40_000.0)
    expect(cuerpo['efectivo_esperado_ars']).to eq(140_000.0)

    # Y al contar exactamente eso, no hay diferencia ni asiento inventado. Se cierra desde el
    # mostrador, que es la única puerta.
    ActsAsTenant.with_tenant(club) do
      mostrador = sede.mostrador!
      # Se cuenta TODO lo que está sobre la mesa: un arqueo que deja algo sin contar no arquea.
      conteos = mostrador.sobre_la_mesa.map { |mi| { stock_id: mi.stock_id, contado: mi.cantidad } }
      res = Mostradores::CerrarCaja.call(turno: mostrador.turno_abierto, usuario: admin,
                                         conteos: conteos, efectivo_contado_ars: 140_000,
                                         fondo_siguiente_ars: 140_000)
      raise "No cerró: #{res.error}" unless res.ok?
    end

    expect(CajaTurno.find(caja['id']).diferencia_ars).to eq(0.0)
    expect(movs.where(categoria: 'diferencia_caja')).to be_empty
  end

  it 'el dispensador no saca plata de la caja: responde quien administra' do
    sacar!(clase: 'retiro', como: ana)

    expect(response).to have_http_status(:forbidden)
  end
end
