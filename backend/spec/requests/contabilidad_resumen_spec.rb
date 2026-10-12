require 'rails_helper'

# AC (Germán, 12-oct-2026, rediseño de Contabilidad aprobado en el lienzo): el resumen dice dónde
# está la plata ahora (cajas abiertas y delivery sin rendir), cuánto se debe y desde cuándo, el
# resultado contra el mes pasado A LA MISMA FECHA, los últimos doce meses y los últimos 20
# movimientos. Lo que el panel de conducción también muestra tiene que decir lo mismo.
RSpec.describe 'Contabilidad — resumen', type: :request do
  let(:club)  { create(:club, features: { 'produccion_dispensa' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:lucia) { create(:user, :dispensador, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'mixta', nombre: 'Centro') }

  before { sign_in_as(admin) }

  def json = JSON.parse(response.body)
  def resumen = (get('/api/movimientos_contables/dashboard') && json)
  def panel = (get('/api/panel_conduccion') && json)

  def mov!(tipo, monto, fecha: Time.zone.today, **extra)
    ActsAsTenant.with_tenant(club) do
      create(:movimiento_contable, club: club, tipo: tipo, monto_ars: monto, fecha: fecha, created_by: admin, **{ pagado: true }.merge(extra))
    end
  end

  # Deja a un paciente debiendo con cargos en fechas dadas: [[monto, hace_dias], ...].
  def deudor!(cargos, pagos: [])
    p = create(:paciente, club: club, created_by: admin)
    cc = p.cuenta_corriente!
    saldo = 0.to_d
    eventos = cargos.map { |m, d| [-m, d] } + pagos.map { |m, d| [m, d] }
    eventos.sort_by { |_, d| -d }.each do |monto, dias|
      nuevo = saldo + monto
      CuentaCorrienteMovimiento.create!(cuenta_corriente: cc, created_by: admin, tipo: monto.negative? ? 'debito' : 'pago',
                                        monto: monto.abs, saldo_anterior: saldo, saldo_nuevo: nuevo,
                                        created_at: dias.days.ago)
      saldo = nuevo
    end
    cc.update!(saldo_disponible: saldo)
    p
  end

  describe 'cuentas por cobrar por antigüedad' do
    it 'un solo deudor: lo que debe toma la edad de sus cargos más recientes (lo pagado cancela lo más viejo)' do
      # Debe 100 de hace 90 días y 50 de hace 10; pagó 100 hace 5. Debe 50, y esos 50 son de hace 10.
      deudor!([[100, 90], [50, 10]], pagos: [[100, 5]])
      r = resumen
      expect(r['por_cobrar']).to eq(50.0)
      expect(r['posicion']['antiguedad']).to eq('hasta_30' => 50.0, 'de_30_a_60' => 0.0, 'mas_de_60' => 0.0)
    end

    it 'varios deudores: cada tramo suma lo de todos y el total cierra con «por cobrar»' do
      deudor!([[100, 90]])
      deudor!([[40, 45], [30, 3]])
      ant = resumen['posicion']['antiguedad']
      expect(ant).to eq('hasta_30' => 30.0, 'de_30_a_60' => 40.0, 'mas_de_60' => 100.0)
      expect(ant.values.sum).to eq(json['por_cobrar'])
      expect(json['posicion']['deudores']).to eq(2)
    end

    it 'el panel de conducción dice el mismo «por cobrar»' do
      deudor!([[120, 20]])
      expect(panel['finanzas']['cuentas_por_cobrar_ars']).to eq(resumen['posicion']['por_cobrar_ars'])
    end
  end

  describe 'dónde está la plata' do
    it 'el efectivo de las cajas abiertas es el mismo que el panel; el delivery sin rendir suma aparte' do
      ActsAsTenant.with_tenant(club) { Mostradores::AbrirCaja.call(mostrador: sede.mostrador!, usuario: lucia, efectivo_contado_ars: 8_000) }
      repartidor = create(:user, :delivery, club: club)
      d = ActsAsTenant.with_tenant(club) do
        stock = create(:stock, club: club, sede: sede, forma_producto: 'flor_seca', unidad: 'g', cantidad: 100, estado: 'asignado')
        Dispensacion.create!(paciente: create(:paciente, club: club, created_by: admin), user: admin, sede: sede,
                             fecha_dispensacion: Time.zone.today, medio_pago: 'efectivo',
                             items_attributes: [{ stock: stock, cantidad: 1 }], aporte_socio_ars: 0)
      end
      Cobro.create!(dispensacion: d, club: club, created_by: repartidor, medio: 'efectivo', contexto: 'entrega', rendido: false, monto_ars: 3_500)

      pos = resumen['posicion']
      expect(pos['efectivo_en_cajas_ars']).to eq(8_000.0)
      expect(pos['cajas_abiertas']).to eq(1)
      expect(pos['delivery_sin_rendir_ars']).to eq(3_500.0)
      expect(pos['disponible_ars']).to eq(11_500.0)
      expect(panel['finanzas']['efectivo_en_cajas_ars']).to eq(8_000.0)
    end
  end

  it 'compara contra el mes pasado hasta el mismo día, no contra el mes entero' do
    travel_to Date.new(2026, 10, 10) do
      mov!('ingreso', 1_000, fecha: Date.new(2026, 9, 5))
      mov!('ingreso', 9_000, fecha: Date.new(2026, 9, 25)) # después del día 10: no entra
      ant = resumen['mes_anterior_a_la_fecha']
      expect(ant['hasta']).to eq('2026-09-10')
      expect(ant['ingresos']).to eq(1_000.0)
    end
  end

  it 'los últimos doce meses corridos, con los meses vacíos en cero' do
    travel_to Date.new(2026, 10, 10) do
      mov!('ingreso', 500, fecha: Date.new(2025, 11, 3))
      mov!('egreso', 200, fecha: Date.new(2026, 10, 1))
      mov!('ingreso', 999, fecha: Date.new(2025, 10, 30)) # hace trece meses: fuera
      serie = resumen['ultimos_12_meses']
      expect(serie.size).to eq(12)
      expect(serie.first).to include('mes' => '2025-11', 'ingresos' => 500.0)
      expect(serie.last).to include('mes' => '2026-10', 'egresos' => 200.0, 'balance' => -200.0)
      expect(serie.sum { |m| m['ingresos'] }).to eq(500.0)
    end
  end

  it 'los últimos movimientos son los 20 más recientes' do
    25.times { |i| mov!('egreso', 10 + i, fecha: Time.zone.today - i) }
    lista = resumen['ultimos_movimientos']
    expect(lista.size).to eq(20)
    expect(lista.first['monto_ars']).to eq(10.0)
    expect(lista.first).to include('medio_pago', 'created_by', 'created_at', 'sede')
  end

  it 'avisa los cierres de caja del mes a cerrar que nadie revisó' do
    travel_to Date.new(2026, 10, 10) do
      t = ActsAsTenant.with_tenant(club) do
        t = Mostradores::AbrirCaja.call(mostrador: sede.mostrador!, usuario: lucia, efectivo_contado_ars: 0).turno
        Mostradores::CerrarCaja.call(turno: t, usuario: lucia, efectivo_contado_ars: 0, conteos: [])
        t
      end
      t.reload.update_columns(cerrado_at: Time.zone.local(2026, 9, 20, 20))
      expect(resumen['cierres_sin_revisar_al_cierre']).to eq(1)
      t.update_columns(revisado_at: Time.current)
      expect(resumen['cierres_sin_revisar_al_cierre']).to eq(0)
    end
  end

  it 'ingresos por concepto y egresos por categoría suman lo mismo que los totales del mes' do
    mov!('ingreso', 1_000)
    mov!('ingreso', 400, pagado: false)   # entregado a cuenta corriente: todavía no es ingreso
    mov!('egreso', 300)
    mov!('ajuste', 50)
    r = resumen
    cats = r['mes_actual']['por_categoria']
    expect(cats.select { |c| %w[ingreso recupero_costo].include?(c['tipo']) }.sum { |c| c['total'] }).to eq(r['mes_actual']['ingresos'])
    expect(cats.select { |c| c['tipo'] == 'egreso' }.sum { |c| c['total'] }).to eq(r['mes_actual']['egresos'])
    expect(cats.map { |c| c['tipo'] }).not_to include('ajuste')
  end

  it 'lo de otra organización no aparece' do
    otro = create(:club)
    ActsAsTenant.with_tenant(otro) do
      create(:paciente, club: otro, created_by: create(:user, :admin, club: otro)).cuenta_corriente!.update!(saldo_disponible: -5_000)
    end
    expect(resumen['posicion']['por_cobrar_ars']).to eq(0.0)
  end
end
