require 'rails_helper'
require Rails.root.join('lib/auditoria_contable')

# LA AUDITORÍA TIENE QUE QUEDARSE CALLADA CON LO QUE ESTÁ BIEN.
#
# Es una herramienta para mirar plata, y su valor entero depende de eso: un aviso que grita en
# falso entrena a ignorar todos los demás, y el día que aparezca un descuadre de verdad nadie lo
# va a leer. Por eso la mitad de estos ejemplos verifican SILENCIO sobre casos legítimos —la
# dispensa mixta que lleva dos asientos, el efectivo que el repartidor todavía no rindió— y no
# sólo que encuentre el problema.
RSpec.describe AuditoriaContable do
  let(:club)     { create(:club) }
  # Las dispensas las crea administración: un dispensador dispensa del MOSTRADOR y necesitaría
  # una caja abierta, que no es lo que se está probando acá.
  let(:ana)      { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, tipo: 'social') }
  let(:lote)     { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }
  let(:paciente) { ActsAsTenant.with_tenant(club) { create(:paciente, club: club) } }

  let!(:stock) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 500, estado: 'asignado', disponibilidad: 'ambas', precio_sugerido_ars: 100)
    end
  end

  # Cuántos hallazgos devuelve. La salida por pantalla no interesa acá.
  def hallazgos
    ActsAsTenant.with_tenant(club) do
      silenciando { described_class.new(club).call }
    end
  end

  def silenciando
    return yield if ENV['VERBOSE']

    original = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = original
  end

  def dispensar!(gramos, medio: 'efectivo')
    ActsAsTenant.with_tenant(club) do
      d = Dispensacion.create!(paciente: paciente, user: ana, stock: stock, sede: sede,
                               cantidad: gramos, medio_pago: medio,
                               aporte_socio_ars: gramos * 100, fecha_dispensacion: Time.zone.today)
      Dispensaciones::AplicarEfectos.new(d, ana).crear_movimiento_contable
      d
    end
  end

  it 'con todo en orden no dice nada' do
    dispensar!(10)

    expect(hallazgos).to eq(0)
  end

  # La forma que tomaría acá el bug que ya mordió en el stock: una reversa que se aplica dos
  # veces al editar dejaría el asiento duplicado. Sube el ingreso del mes y no falta nada que
  # mirar: sobra.
  it 'canta un asiento duplicado' do
    d = dispensar!(10)
    # A mano y no repitiendo `crear_movimiento_contable`, que desde el arreglo es idempotente y
    # ya no puede duplicar. Lo que se prueba acá es que la auditoría lo VEA si aparece por
    # cualquier otro camino: es la red, no el candado.
    ActsAsTenant.with_tenant(club) do
      original = d.movimientos_contables.first
      MovimientoContable.create!(original.attributes.except('id', 'created_at', 'updated_at'))
    end

    expect(hallazgos).to eq(1)
  end

  it 'canta una dispensa cobrada que no dejó asiento' do
    ActsAsTenant.with_tenant(club) do
      Dispensacion.create!(paciente: paciente, user: ana, stock: stock, sede: sede,
                           cantidad: 10, medio_pago: 'efectivo', aporte_socio_ars: 1_000,
                           fecha_dispensacion: Time.zone.today)
    end

    expect(hallazgos).to eq(1)
  end

  # Una dispensa pagada mitad en efectivo y mitad a cuenta corriente lleva DOS asientos de la
  # misma categoría, y está perfecta: lo que tiene que cerrar es el total.
  it 'no se queja de una dispensa mixta, que legítimamente lleva dos asientos' do
    ActsAsTenant.with_tenant(club) do
      cc = paciente.cuenta_corriente || CuentaCorriente.create!(club: club, paciente: paciente,
                                                               saldo_disponible: 0, limite_credito: 100_000)
      cc.update!(limite_credito: 100_000)
      d = Dispensacion.create!(paciente: paciente, user: ana, stock: stock, sede: sede,
                               cantidad: 10, medio_pago: 'cuenta_corriente',
                               aporte_socio_ars: 1_000, monto_credito_ars: 600,
                               fecha_dispensacion: Time.zone.today)
      Dispensaciones::AplicarEfectos.new(d, ana).crear_movimiento_contable
      expect(d.movimientos_contables.count).to eq(2)
    end

    expect(hallazgos).to eq(0)
  end

  # El efectivo que cobró el repartidor y todavía no rindió NO tiene asiento a propósito: esa
  # plata está en su bolsillo hasta que la entrega. Marcarlo como descuadre sería quejarse de que
  # el sistema funciona.
  it 'no se queja del efectivo que el repartidor todavía no rindió' do
    ActsAsTenant.with_tenant(club) do
      repartidor = create(:user, :delivery, club: club)
      d = Dispensacion.create!(paciente: paciente, user: ana, stock: stock, sede: sede,
                               cantidad: 10, medio_pago: 'efectivo', aporte_socio_ars: 1_000,
                               fecha_dispensacion: Time.zone.today, delivery_id: repartidor.id,
                               estado_envio: 'entregado')
      Dispensaciones::RegistrarCobro.call(dispensacion: d, club: club, usuario: repartidor,
                                          medio: 'efectivo', monto: 1_000, contexto: 'entrega')
      expect(d.movimientos_contables.count).to eq(0)
    end

    expect(hallazgos).to eq(0)
  end

  it 'canta un saldo de cuenta corriente que se despegó de su historial' do
    ActsAsTenant.with_tenant(club) do
      cc = paciente.cuenta_corriente || CuentaCorriente.create!(club: club, paciente: paciente,
                                                               saldo_disponible: 0, limite_credito: 0)
      cc.movimientos.create!(tipo: 'carga', monto: 5_000, saldo_anterior: 0, saldo_nuevo: 5_000,
                             descripcion: 'carga', created_by: ana)
      cc.update_columns(saldo_disponible: 9_999)   # alguien escribió el saldo sin dejar rastro
    end

    expect(hallazgos).to eq(1)
  end
end
