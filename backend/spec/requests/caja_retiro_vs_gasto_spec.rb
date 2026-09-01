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
    post "/api/sedes/#{sede.id}/caja/abrir", headers: auth_headers, params: { monto_inicial_ars: 200_000 }
    JSON.parse(response.body)
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
    caja # abre
    abrir_mostrador!(sede, usuario: admin)

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

    # Y al contar exactamente eso, no hay diferencia ni asiento inventado.
    sign_in_as(admin)
    post "/api/sedes/#{sede.id}/caja/#{caja['id']}/cerrar",
         headers: auth_headers, params: { efectivo_declarado_ars: 140_000 }

    expect(JSON.parse(response.body)['diferencia_ars']).to eq(0.0)
    expect(movs.where(categoria: 'diferencia_caja')).to be_empty
  end

  it 'el dispensador no saca plata de la caja: responde quien administra' do
    sacar!(clase: 'retiro', como: ana)

    expect(response).to have_http_status(:forbidden)
  end
end
