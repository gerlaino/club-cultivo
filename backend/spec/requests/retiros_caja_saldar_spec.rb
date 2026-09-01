require 'rails_helper'

# AC (Germán): "deberíamos agregar eso que falta para la devolución, o quizás asentarlo como
# adelanto".
#
# La decisión, y es la parte importante: el retiro nace NEUTRO y es el CIERRE el que define qué
# fue contablemente. Cuando alguien saca plata del cajón todavía no está decidido si la devuelve,
# trae la factura o se la descuentan; asentarlo como egreso de entrada obligaría a deshacer un
# asiento cada vez que la realidad resulta otra.
#
# Y el saldo de cada persona no se guarda en ningún lado: sale de sumar sus retiros abiertos. Un
# saldo almacenado y sus movimientos son dos datos que hay que mantener coincidiendo.
RSpec.describe 'Saldar un retiro de caja', type: :request do
  include AuthHelpers

  let(:club)       { create(:club) }
  let(:admin)      { create(:user, :admin, club: club) }
  let(:supervisor) { create(:user, :supervisor, club: club) }
  let(:ana)        { create(:user, :dispensador, club: club) }
  let(:sede)       { create(:sede, club: club, tipo: 'social') }

  def retiro!(monto: 100_000, de: admin, motivo: 'para el proveedor')
    ActsAsTenant.with_tenant(club) do
      MovimientoContable.create!(
        club: club, sede: sede, created_by: admin, retirado_por: de,
        tipo: 'ajuste', categoria: 'retiro_caja',
        descripcion: "Retiro de caja — #{motivo}", monto_ars: monto, fecha: Time.zone.today,
        pagado: true, medio_pago: 'efectivo', comprobante_tipo: 'sin_comprobante'
      )
    end
  end

  def saldar!(mov, forma:, como: admin, **extra)
    sign_in_as(como)
    post "/api/retiros_caja/#{mov.id}/saldar", headers: auth_headers,
         params: { forma: forma }.merge(extra)
    JSON.parse(response.body)
  end

  def movs = ActsAsTenant.with_tenant(club) { MovimientoContable.where(club_id: club.id) }

  describe 'el saldo de cada persona' do
    it 'sale de sumar sus retiros abiertos, sin guardarse en ningún lado' do
      retiro!(monto: 100_000, de: admin)
      retiro!(monto: 30_000,  de: admin)
      retiro!(monto: 50_000,  de: supervisor)

      sign_in_as(admin)
      get '/api/retiros_caja', headers: auth_headers
      data = JSON.parse(response.body)

      del_admin = data['por_persona'].find { |p| p['user_id'] == admin.id }
      expect(del_admin['debe']).to eq(130_000.0)
      expect(data['total_abierto']).to eq(180_000.0)
    end

    it 'lo saldado deja de contar' do
      uno = retiro!(monto: 100_000)
      retiro!(monto: 30_000)

      saldar!(uno, forma: 'devuelto')

      sign_in_as(admin)
      get '/api/retiros_caja', headers: auth_headers
      data = JSON.parse(response.body)

      expect(data['total_abierto']).to eq(30_000.0)
      expect(data['saldados'].map { |s| s['id'] }).to include(uno.id)
    end
  end

  describe 'devolvió la plata' do
    it 'no genera ningún gasto: se compensa' do
      mov = retiro!

      expect { saldar!(mov, forma: 'devuelto') }.not_to change { movs.egresos.sum(:monto_ars) }
      expect(mov.reload.saldado_como).to eq('devuelto')
    end

    # La plata reaparece en el cajón HOY, no en el turno del retiro, que ya cerró su arqueo.
    it 'la espera el turno que está corriendo' do
      caja = ActsAsTenant.with_tenant(club) do
        CajaTurno.create!(club: club, sede: sede, punto: sede.mostrador!, abierta_por: admin,
                          monto_inicial_ars: 10_000, abierta_at: Time.current, estado: 'abierta')
      end
      mov = retiro!(monto: 100_000)

      saldar!(mov, forma: 'devuelto')

      devolucion = movs.where(categoria: 'devolucion_caja').last
      expect(devolucion.caja_turno_id).to eq(caja.id)
    end
  end

  describe 'trajo comprobante' do
    it 'recién ahí se convierte en un gasto real, con su categoría' do
      mov = retiro!

      saldar!(mov, forma: 'comprobante', categoria: 'insumo', notas: 'sustrato')

      egreso = movs.egresos.last
      expect(egreso.categoria).to eq('insumo')
      expect(egreso.monto_ars).to eq(100_000)
      expect(egreso.descripcion).to include('sustrato')
      expect(mov.reload.saldado_como).to eq('comprobante')
    end

    it 'sin categoría no se puede cerrar: un gasto sin categoría no se puede leer después' do
      mov = retiro!

      cuerpo = saldar!(mov, forma: 'comprobante')

      expect(response).to have_http_status(:unprocessable_entity)
      expect(cuerpo['error']).to match(/categoría/i)
      expect(mov.reload.saldado_at).to be_nil
    end

    # El egreso NO vuelve a descontar del cajón: el retiro ya lo hizo en su turno.
    it 'el egreso no se engancha a ninguna caja' do
      ActsAsTenant.with_tenant(club) do
        CajaTurno.create!(club: club, sede: sede, punto: sede.mostrador!, abierta_por: admin,
                          monto_inicial_ars: 10_000, abierta_at: Time.current, estado: 'abierta')
      end
      mov = retiro!

      saldar!(mov, forma: 'comprobante', categoria: 'insumo')

      expect(movs.egresos.last.caja_turno_id).to be_nil
    end
  end

  describe 'se le descuenta del sueldo' do
    it 'genera un egreso de sueldo: es el adelanto, decidido al cerrar' do
      mov = retiro!(de: supervisor)

      saldar!(mov, forma: 'sueldo')

      egreso = movs.egresos.last
      expect(egreso.categoria).to eq('sueldo')
      expect(egreso.descripcion).to include(supervisor.nombre_completo)
    end
  end

  describe 'los bordes' do
    it 'no se salda dos veces' do
      mov = retiro!
      saldar!(mov, forma: 'devuelto')

      cuerpo = saldar!(mov, forma: 'sueldo')

      expect(response).to have_http_status(:unprocessable_entity)
      expect(cuerpo['error']).to match(/ya estaba saldado/i)
    end

    it 'el dispensador no ve ni salda retiros: es plata de la organización' do
      mov = retiro!
      saldar!(mov, forma: 'devuelto', como: ana)
      expect(response).to have_http_status(:forbidden)

      sign_in_as(ana)
      get '/api/retiros_caja', headers: auth_headers
      expect(response).to have_http_status(:forbidden)
    end

    it 'no se puede saldar el retiro de otra organización' do
      ajeno = create(:club)
      otro = ActsAsTenant.with_tenant(ajeno) do
        adm = create(:user, :admin, club: ajeno)
        MovimientoContable.create!(club: ajeno, created_by: adm, retirado_por: adm,
                                   tipo: 'ajuste', categoria: 'retiro_caja',
                                   descripcion: 'Retiro de caja — ajeno', monto_ars: 1_000,
                                   fecha: Time.zone.today, pagado: true, medio_pago: 'efectivo',
                                   comprobante_tipo: 'sin_comprobante')
      end

      saldar!(otro, forma: 'devuelto')

      expect(response).to have_http_status(:not_found)
    end
  end
end
