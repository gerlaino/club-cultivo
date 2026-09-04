require 'rails_helper'

# UN ARQUEO FIRMADO NO SE MUEVE DESPUÉS.
#
# `efectivo_esperado_ars` se calcula EN VIVO cada vez que alguien lo mira, también en un turno ya
# cerrado. Sus componentes ignoran a propósito lo posterior al cierre (`salidas`, `ingresos`,
# `otros_ingresos_efectivo` filtran por `cerrada_at`) justamente para que la diferencia de arqueo
# no cambie después — la regla ya estaba escrita para el retiro de la recaudación.
#
# Lo cobrado quedó afuera de esa regla: cancelar o editar una dispensa de ayer soft-borra sus
# `Cobro`, y el esperado de un turno que cerró CUADRADO pasa a mostrar un sobrante que nadie
# puede explicar. Es la peor forma de un error contable: no hay nada que mirar que te delate,
# porque el número se recalcula solo.
RSpec.describe 'El arqueo de un turno cerrado no cambia después', type: :model do
  let(:club)     { create(:club) }
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

  def dispensar_en_efectivo!(gramos)
    ActsAsTenant.with_tenant(club) do
      d = Dispensacion.create!(paciente: paciente, user: ana, stock: stock, sede: sede,
                               cantidad: gramos, medio_pago: 'efectivo',
                               aporte_socio_ars: gramos * 100, fecha_dispensacion: Time.zone.today)
      Dispensaciones::RegistrarCobro.call(dispensacion: d, club: club, usuario: ana,
                                          medio: 'efectivo', monto: gramos * 100,
                                          contexto: 'creacion')
      d
    end
  end

  it 'cancelar una dispensa de ayer no mueve la diferencia de un arqueo ya firmado' do
    ActsAsTenant.with_tenant(club) do
      Mostradores::Cargar.call(mostrador: sede.mostrador!, usuario: ana, motivo: 'carga',
                               cambios: [{ stock_id: stock.id, cantidad: 300 }])
      Mostradores::AbrirCaja.call(mostrador: sede.mostrador!, usuario: ana,
                                  efectivo_contado_ars: 50_000)

      dispensa = dispensar_en_efectivo!(85)   # $8.500 en el cajón
      caja     = sede.mostrador!.turno_abierto.caja_turno

      # Cierra CUADRADO: cuenta exactamente lo que el sistema esperaba.
      esperado = caja.efectivo_esperado_ars
      Mostradores::CerrarCaja.call(turno: sede.mostrador!.turno_abierto, usuario: ana,
                                   conteos: [{ stock_id: stock.id, contado: 215 }],
                                   efectivo_contado_ars: esperado)
      caja.reload
      expect(caja.diferencia_ars).to eq(0.0)

      # Al día siguiente se cancela esa dispensa (un reparto que volvió, un error, lo que sea).
      Dispensaciones::Cancelar.call(dispensacion: dispensa, usuario: ana, motivo: 'prueba')

      # El arqueo de ayer ya está firmado: no puede moverse por algo que pasó hoy.
      expect(caja.reload.diferencia_ars).to eq(0.0)
    end
  end

  # Congelar el arqueo no puede volverse "contar plata que no estaba": lo cancelado DURANTE el
  # turno sí sale de lo esperado, porque a la hora de contar ese efectivo ya no estaba en el
  # cajón. Sin este caso, el arreglo del anterior se pasaría de largo y el turno cerraría con un
  # faltante inventado.
  it 'lo cancelado ANTES de cerrar sí baja lo esperado' do
    ActsAsTenant.with_tenant(club) do
      Mostradores::Cargar.call(mostrador: sede.mostrador!, usuario: ana, motivo: 'carga',
                               cambios: [{ stock_id: stock.id, cantidad: 300 }])
      Mostradores::AbrirCaja.call(mostrador: sede.mostrador!, usuario: ana,
                                  efectivo_contado_ars: 50_000)

      dispensa = dispensar_en_efectivo!(85)
      caja     = sede.mostrador!.turno_abierto.caja_turno
      expect(caja.efectivo_esperado_ars).to eq(58_500.0)

      Dispensaciones::Cancelar.call(dispensacion: dispensa, usuario: ana, motivo: 'se arrepintió')

      expect(caja.reload.efectivo_esperado_ars).to eq(50_000.0)
    end
  end

  # El buffet tiene el mismo agujero por el mismo motivo: `BarVenta` también es soft-delete y una
  # venta se deshace desde la venta. Con la caja cerrada, deshacerla movía su arqueo.
  it 'deshacer una venta del buffet no mueve el arqueo ya cerrado' do
    ActsAsTenant.with_tenant(club) do
      barra = create(:barra, club: club, sede: sede)
      caja  = CajaTurno.create!(club: club, sede: sede, punto_type: 'Barra', punto_id: barra.id,
                                abierta_por: ana, estado: 'abierta', monto_inicial_ars: 10_000,
                                abierta_at: Time.current)
      venta = create(:bar_venta, club: club, bar: barra, user: ana, caja_turno: caja,
                     total_ars: 5_000, medio_pago: 'efectivo')

      esperado = caja.efectivo_esperado_ars
      expect(esperado).to eq(15_000.0)
      caja.update!(estado: 'cerrada', cerrada_at: Time.current, cerrada_por: ana,
                   efectivo_declarado_ars: esperado)
      expect(caja.diferencia_ars).to eq(0.0)

      venta.destroy   # se deshace al día siguiente

      expect(caja.reload.diferencia_ars).to eq(0.0)
    end
  end
end
