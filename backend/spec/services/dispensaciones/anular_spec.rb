require 'rails_helper'

# UNA DISPENSA NO SE BORRA: SE ANULA, Y DICE POR QUÉ (Germán, 13-sep-2026).
#
# Son hechos distintos y se deshacen distinto:
#   · error de carga    → nunca pasó: asiento borrado, cobros afuera, producto de vuelta.
#   · devolución        → pasó y se deshizo: la venta queda y se escribe la devolución al lado; el
#                         producto vuelve como cuando el repartidor trae el paquete.
#   · producto defectuoso → como la devolución, pero el producto sale como merma.
RSpec.describe Dispensaciones::Cancelar, 'anular con motivo' do
  let(:club)     { create(:club) }
  let(:ana)      { create(:user, :dispensador, club: club) }
  let(:sede)     { create(:sede, club: club, tipo: 'mixta') }
  let(:lote)     { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }
  let(:paciente) { ActsAsTenant.with_tenant(club) { create(:paciente, club: club) } }

  let!(:stock) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 500, estado: 'asignado', disponibilidad: 'ambas', precio_sugerido_ars: 100)
    end
  end

  def abrir!(fondo = 50_000)
    Mostradores::Cargar.call(mostrador: sede.mostrador!, usuario: ana, motivo: 'carga',
                             cambios: [{ stock_id: stock.id, cantidad: 300 }])
    Mostradores::AbrirCaja.call(mostrador: sede.mostrador!, usuario: ana, efectivo_contado_ars: fondo)
    sede.mostrador!.turno_abierto.caja_turno
  end

  def dispensar!(gramos, medio: 'efectivo')
    d = Dispensacion.create!(paciente: paciente, user: ana, stock: stock, sede: sede,
                             cantidad: gramos, medio_pago: medio,
                             aporte_socio_ars: gramos * 100, fecha_dispensacion: Time.zone.today)
    Dispensaciones::RegistrarCobro.call(dispensacion: d, club: club, usuario: ana,
                                        medio: medio, monto: gramos * 100, contexto: 'creacion')
    d
  end

  def mesa = MostradorItem.unscoped.find_by(mostrador: sede.mostrador!, stock_id: stock.id).cantidad.to_d

  around { |ex| ActsAsTenant.with_tenant(club) { ex.run } }

  it 'rechaza un motivo que no existe' do
    abrir!
    d = dispensar!(10)
    res = described_class.call(dispensacion: d, usuario: ana, motivo: 'porque sí')
    expect(res.ok?).to be false
    expect(d.reload.cancelada?).to be false
  end

  context 'error de carga' do
    it 'borra el asiento y los cobros, y el producto vuelve a la mesa' do
      caja = abrir!
      d    = dispensar!(85)
      expect(caja.efectivo_esperado_ars).to eq(58_500.0)

      res = described_class.call(dispensacion: d, usuario: ana, motivo: 'error_carga', nota: 'me equivoqué de paciente')
      expect(res.ok?).to be(true), res.error

      d.reload
      expect(d).to be_cancelada
      expect(d.motivo_anulacion).to eq('error_carga')
      expect(d.nota_anulacion).to eq('me equivoqué de paciente')
      expect(d.anulada_por).to eq(ana)
      expect(d.anulada_at).to be_present
      expect(d.movimientos_contables).to be_empty
      expect(d.cobros).to be_empty
      expect(caja.reload.efectivo_esperado_ars).to eq(50_000.0)
      expect(stock.reload.cantidad.to_d).to eq(500)
      expect(mesa).to eq(300)
    end
  end

  context 'devolución del paciente' do
    it 'con la caja abierta: la venta queda, sale la devolución del cajón y el producto vuelve a la mesa' do
      caja = abrir!
      d    = dispensar!(85)

      res = described_class.call(dispensacion: d, usuario: ana, motivo: 'devolucion', nota: 'se arrepintió')
      expect(res.ok?).to be true

      d.reload
      expect(d.motivo_anulacion).to eq('devolucion')
      # El ingreso sigue ahí y el cobro también: esa plata entró al cajón de verdad.
      expect(d.cobros.count).to eq(1)
      expect(d.movimientos_contables.select(&:es_ingreso?)).not_to be_empty
      egreso = d.movimientos_contables.find_by(tipo: 'egreso', categoria: 'devolucion_paciente')
      expect(egreso).to be_present
      expect(egreso.monto_ars.to_d).to eq(8_500)
      expect(egreso.medio_pago).to eq('efectivo')
      expect(egreso.pagado).to be true
      expect(egreso.fecha_pago).to eq(Time.zone.today)
      expect(egreso.caja_turno_id).to eq(caja.id)
      # +8.500 −8.500: el cajón tiene lo que tenía.
      expect(caja.reload.efectivo_esperado_ars).to eq(50_000.0)
      expect(stock.reload.cantidad.to_d).to eq(500)
      expect(mesa).to eq(300)
    end

    it 'al día siguiente: el arqueo de ayer no se mueve y la plata sale de la caja de hoy' do
      caja_ayer = abrir!
      d         = dispensar!(85)
      Mostradores::CerrarCaja.call(turno: sede.mostrador!.turno_abierto, usuario: ana,
                                   conteos: [{ stock_id: stock.id, contado: 215 }],
                                   efectivo_contado_ars: caja_ayer.efectivo_esperado_ars)
      expect(caja_ayer.reload.diferencia_ars).to eq(0.0)

      caja_hoy = abrir!(20_000)
      res = described_class.call(dispensacion: d, usuario: ana, motivo: 'devolucion')
      expect(res.ok?).to be true

      expect(caja_ayer.reload.diferencia_ars).to eq(0.0)
      expect(caja_ayer.efectivo_esperado_ars).to eq(58_500.0)
      expect(caja_hoy.reload.efectivo_esperado_ars).to eq(11_500.0)
    end

    it 'por transferencia: la devolución queda pendiente hasta que se registre el pago' do
      abrir!
      d = dispensar!(20, medio: 'transferencia')

      described_class.call(dispensacion: d, usuario: ana, motivo: 'devolucion')

      egreso = d.movimientos_contables.find_by(tipo: 'egreso', categoria: 'devolucion_paciente')
      expect(egreso.medio_pago).to eq('transferencia')
      expect(egreso.pagado).to be false
      expect(egreso.caja_turno_id).to be_nil
    end

    it 'si el producto no se puede volver a entregar, sale como merma y no vuelve a la mesa' do
      abrir!
      d = dispensar!(85)

      described_class.call(dispensacion: d, usuario: ana, motivo: 'devolucion', descartar_producto: true)

      expect(stock.reload.cantidad.to_d).to eq(415)
      expect(mesa).to eq(215)
      merma = stock.stock_movimientos.find_by(tipo: 'merma')
      expect(merma.gramos.to_d).to eq(-85)
      expect(stock.stock_movimientos.where(tipo: 'dispensacion')).to be_empty
    end
  end

  context 'cómo vuelve la plata' do
    it 'por el medio que se elige, no por el que pagó: pagó en efectivo y se lleva transferencia' do
      caja = abrir!
      d    = dispensar!(85)

      res = described_class.call(dispensacion: d, usuario: ana, motivo: 'devolucion', devolucion: { medio: 'transferencia' })
      expect(res.ok?).to be(true), res.error

      egreso = d.movimientos_contables.find_by(tipo: 'egreso', categoria: 'devolucion_paciente')
      expect(egreso.medio_pago).to eq('transferencia')
      expect(egreso.pagado).to be false
      # El cobro en efectivo queda en el cajón: no salió nada de ahí.
      expect(caja.reload.efectivo_esperado_ars).to eq(58_500.0)
    end

    it 'en efectivo tiene que alcanzar lo que hay en la caja' do
      abrir!(1_000)
      d = dispensar!(85) # cajón: 1.000 + 8.500

      Mostradores::CerrarCaja.call(turno: sede.mostrador!.turno_abierto, usuario: ana,
                                   conteos: [{ stock_id: stock.id, contado: 215 }], efectivo_contado_ars: 9_500)
      abrir!(2_000) # hoy hay $2.000 y hay que devolver $8.500

      res = described_class.call(dispensacion: d, usuario: ana, motivo: 'devolucion', devolucion: { medio: 'efectivo' })
      expect(res.ok?).to be false
      expect(res.error).to include('hay $2.000')
      expect(res.error).to include('devolver $8.500')
      expect(d.reload.cancelada?).to be false
    end

    it 'administración elige la caja, o ninguna' do
      abrir!
      d = dispensar!(20)
      res = described_class.call(dispensacion: d, usuario: ana, motivo: 'devolucion',
                                 devolucion: { medio: 'efectivo', caja_turno_id: nil })
      expect(res.ok?).to be(true), res.error
      expect(d.movimientos_contables.find_by(categoria: 'devolucion_paciente').caja_turno_id).to be_nil
    end
  end

  context 'cambio del producto' do
    it 'sólo por producto defectuoso' do
      abrir!
      d = dispensar!(10)
      res = described_class.call(dispensacion: d, usuario: ana, motivo: 'devolucion', resolucion: 'cambio')
      expect(res.ok?).to be false
      expect(res.error).to include('defectuoso')
    end

    it 'no devuelve plata: la venta queda y cubre lo que se lleve después; el defectuoso sale como merma' do
      caja = abrir!
      d    = dispensar!(10)

      res = described_class.call(dispensacion: d, usuario: ana, motivo: 'producto_defectuoso', resolucion: 'cambio', nota: 'roto')
      expect(res.ok?).to be(true), res.error

      d.reload
      expect(d.resolucion_anulacion).to eq('cambio')
      expect(d.cambio_pendiente?).to be true
      expect(d.movimientos_contables.where(categoria: 'devolucion_paciente')).to be_empty
      expect(d.cobros.count).to eq(1)
      expect(caja.reload.efectivo_esperado_ars).to eq(51_000.0)
      expect(stock.reload.cantidad.to_d).to eq(490)
      expect(stock.stock_movimientos.find_by(tipo: 'merma').gramos.to_d).to eq(-10)
    end
  end

  context 'producto defectuoso' do
    it 'devuelve la plata y el producto sale como merma sin que nadie lo pida' do
      caja = abrir!
      d    = dispensar!(10)

      res = described_class.call(dispensacion: d, usuario: ana, motivo: 'producto_defectuoso', nota: 'preroll roto')
      expect(res.ok?).to be true

      expect(d.movimientos_contables.where(tipo: 'egreso', categoria: 'devolucion_paciente').count).to eq(1)
      expect(caja.reload.efectivo_esperado_ars).to eq(50_000.0)
      expect(stock.reload.cantidad.to_d).to eq(490)
      expect(mesa).to eq(290)
      expect(stock.stock_movimientos.find_by(tipo: 'merma').notas).to include('preroll roto')
    end
  end
end
