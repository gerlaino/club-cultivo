require 'rails_helper'

# EL ASIENTO NO SE PUEDE APLICAR DOS VECES.
#
# El bug que mordió en el stock fue una reversa aplicada dos veces al editar: el historial quedaba
# perfecto y el contador mentía. En contabilidad ese mismo error toma la peor forma posible: un
# ingreso repetido no deja hueco que mirar —no falta una fila, SOBRA— y lo único que se ve es un
# resultado del mes más alto de lo que fue.
#
# `debitar_cuenta_corriente` ya se protegía ("evita doble débito"); el asiento no. Ahora sí, y por
# el mismo criterio: la operación se puede repetir sin miedo, que es lo que hace que un reintento,
# una edición o una restauración no puedan romper la contabilidad.
RSpec.describe Dispensaciones::AplicarEfectos do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, tipo: 'social') }
  let(:lote)     { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }
  let(:paciente) { ActsAsTenant.with_tenant(club) { create(:paciente, club: club) } }

  let!(:stock) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 500, estado: 'asignado', disponibilidad: 'ambas', precio_sugerido_ars: 100)
    end
  end

  def dispensa(medio: 'efectivo', credito: 0)
    ActsAsTenant.with_tenant(club) do
      Dispensacion.create!(paciente: paciente, user: admin, stock: stock, sede: sede,
                           cantidad: 10, medio_pago: medio, aporte_socio_ars: 1_000,
                           monto_credito_ars: credito, fecha_dispensacion: Time.zone.today)
    end
  end

  it 'aplicado dos veces deja UN asiento, no dos' do
    d = dispensa

    ActsAsTenant.with_tenant(club) do
      2.times { described_class.new(d, admin).crear_movimiento_contable }

      expect(d.movimientos_contables.count).to eq(1)
      expect(d.movimientos_contables.sum(:monto_ars)).to eq(1_000)
    end
  end

  # La mixta lleva dos asientos —uno por el crédito y otro por el efectivo— y tiene que seguir
  # llevándolos: la protección es contra el DUPLICADO, no contra el segundo asiento legítimo.
  it 'no se come el segundo asiento de una dispensa mixta' do
    d = dispensa(medio: 'cuenta_corriente', credito: 600)

    ActsAsTenant.with_tenant(club) do
      described_class.new(d, admin).crear_movimiento_contable

      expect(d.movimientos_contables.count).to eq(2)
      expect(d.movimientos_contables.sum(:monto_ars)).to eq(1_000)
    end
  end

  # Al editar una dispensa, el controller borra los asientos viejos y aplica los nuevos. Ese
  # borrado es lógico, así que la idempotencia tiene que mirar sólo los vivos: si contara los
  # borrados, editar el monto dejaría la dispensa SIN asiento — el error opuesto y peor.
  it 'después de borrar los asientos, vuelve a crearlos' do
    d = dispensa

    ActsAsTenant.with_tenant(club) do
      described_class.new(d, admin).crear_movimiento_contable
      d.movimientos_contables.destroy_all
      d.reload
      described_class.new(d, admin).crear_movimiento_contable

      expect(d.movimientos_contables.count).to eq(1)
    end
  end
end
