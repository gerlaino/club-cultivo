require 'rails_helper'

# El MOSTRADOR como punto de venta del dispensario, hermano de la `Barra` del buffet.
#
# Antes la caja del dispensario apuntaba a la `Sede` porque esta entidad no existía, y la
# pregunta "¿cuál es la caja de esta sede?" estaba escrita a mano —`punto_type: 'Sede'`— en cinco
# archivos. Ninguno tiraba error al quedar desactualizado: simplemente no encontraban caja, el
# cobro quedaba suelto y el arqueo mentía en silencio. Por eso estos ejemplos.
RSpec.describe 'El mostrador como punto de venta', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'social') }

  describe 'Sede#mostrador' do
    it 'lo crea la primera vez que hace falta' do
      expect { sede.mostrador }.to change { Mostrador.unscoped.where(sede_id: sede.id).count }.from(0).to(1)
    end

    # Perezoso pero idempotente: se lo llama desde cada request de caja, y sin esto una sede
    # terminaba con un mostrador por visita.
    it 'devuelve siempre el mismo, no uno nuevo por llamada' do
      primero = sede.mostrador
      sede.mostradores.reset

      expect(sede.mostrador.id).to eq(primero.id)
      expect(Mostrador.unscoped.where(sede_id: sede.id).count).to eq(1)
    end

    it 'una sede de producción no tiene mostrador: no atiende pacientes' do
      produccion = create(:sede, club: club, tipo: 'produccion')

      expect(produccion.mostrador).to be_nil
      expect(Mostrador.unscoped.where(sede_id: produccion.id).count).to eq(0)
    end

    # Sólo la CREACIÓN se restringe. Una sede que cambió de tipo no puede perder acceso a su
    # mostrador: ahí adentro hay turnos cerrados y plata.
    it 'una sede que ya tiene mostrador lo conserva aunque deje de ser social' do
      mostrador = sede.mostrador
      sede.update_column(:tipo, 'produccion')

      expect(sede.reload.mostrador.id).to eq(mostrador.id)
    end

    it 'la sede mixta también dispensa' do
      mixta = create(:sede, club: club, tipo: 'mixta')

      expect(mixta.mostrador).to be_present
    end
  end

  describe 'la caja se abre contra el mostrador' do
    it 'la caja del dispensario apunta al Mostrador, no a la Sede' do
      caja = ActsAsTenant.with_tenant(club) do
        CajaTurno.create!(club: club, sede: sede, punto: sede.mostrador, abierta_por: admin,
                          monto_inicial_ars: 5_000, abierta_at: Time.current, estado: 'abierta')
      end

      expect(caja.punto_type).to eq('Mostrador')
      expect(caja).to be_de_dispensario
      expect(caja).not_to be_de_bar
    end

    it 'CajaTurno.abierta_en_sede la encuentra por la sede, que es como la piensa el usuario' do
      caja = ActsAsTenant.with_tenant(club) do
        CajaTurno.create!(club: club, sede: sede, punto: sede.mostrador, abierta_por: admin,
                          monto_inicial_ars: 5_000, abierta_at: Time.current, estado: 'abierta')
      end

      expect(CajaTurno.abierta_en_sede(club_id: club.id, sede_id: sede.id)&.id).to eq(caja.id)
    end

    it 'una caja cerrada no cuenta como abierta' do
      ActsAsTenant.with_tenant(club) do
        CajaTurno.create!(club: club, sede: sede, punto: sede.mostrador, abierta_por: admin,
                          monto_inicial_ars: 5_000, abierta_at: 1.day.ago, estado: 'cerrada',
                          efectivo_declarado_ars: 5_000, cerrada_at: 1.day.ago)
      end

      expect(CajaTurno.abierta_en_sede(club_id: club.id, sede_id: sede.id)).to be_nil
    end

    # La barrera primaria sigue siendo el scoping explícito por club_id: `abierta_en_sede` corre
    # con `unscoped` (la llaman servicios sin tenant fijado), así que si el club_id no filtrara,
    # la caja de otra organización sería alcanzable.
    it 'no encuentra la caja de otra organización' do
      otro       = create(:club)
      otro_admin = create(:user, :admin, club: otro)
      otra_sede  = create(:sede, club: otro, tipo: 'social')
      ActsAsTenant.with_tenant(otro) do
        CajaTurno.create!(club: otro, sede: otra_sede, punto: otra_sede.mostrador,
                          abierta_por: otro_admin, monto_inicial_ars: 9_000,
                          abierta_at: Time.current, estado: 'abierta')
      end

      expect(CajaTurno.abierta_en_sede(club_id: club.id, sede_id: otra_sede.id)).to be_nil
    end
  end

  # El bug que ya existía: `RecibirCajaDelivery` buscaba la caja abierta MÁS RECIENTE de
  # cualquier sede, sin filtrar. Con dos sedes con caja abierta, el efectivo del repartidor caía
  # en la que había abierto más tarde — sobrante en una, faltante en la otra, y nada que lo
  # explicara.
  describe 'la rendición del repartidor con más de una sede' do
    let(:repartidor) { create(:user, :delivery, club: club) }
    let(:norte)      { create(:sede, club: club, tipo: 'social', nombre: 'Norte') }
    let(:centro)     { create(:sede, club: club, tipo: 'social', nombre: 'Centro') }

    def abrir_caja!(en_sede, hace:)
      ActsAsTenant.with_tenant(club) do
        CajaTurno.create!(club: club, sede: en_sede, punto: en_sede.mostrador, abierta_por: admin,
                          monto_inicial_ars: 1_000, abierta_at: hace, estado: 'abierta')
      end
    end

    def dispensacion_con_envio
      ActsAsTenant.with_tenant(club) do
        lote  = create(:lote, club: club, sala: create(:sala, club: club, sede: norte))
        stock = create(:stock, club: club, sede: norte, lote: lote, forma_producto: 'flor_seca',
                               cantidad: 500, precio_sugerido_ars: 100)
        Dispensacion.create!(paciente: create(:paciente, club: club), user: admin, stock: stock,
                             sede: norte, cantidad: 5, medio_pago: 'efectivo',
                             aporte_socio_ars: 8_000, fecha_dispensacion: Time.zone.today,
                             con_envio: true, delivery_id: repartidor.id,
                             direccion_envio: 'Falsa 123', contacto_nombre: 'Ana')
      end
    end

    it 'la plata entra en el mostrador del que la recibe, no en el que abrió más tarde' do
      caja_norte = abrir_caja!(norte,  hace: 3.hours.ago)
      abrir_caja!(centro, hace: 1.hour.ago) # la más reciente: la que se llevaba la plata antes
      # El receptor atiende Norte, y ahí es donde el repartidor le entrega el efectivo.
      UserSede.create!(user: admin, sede: norte)

      disp = dispensacion_con_envio
      cobro = ActsAsTenant.with_tenant(club) do
        Dispensaciones::RegistrarCobro.call(dispensacion: disp, club: club, usuario: repartidor,
                                            medio: 'efectivo', monto: 8_000, contexto: 'entrega').cobro
      end
      ActsAsTenant.with_tenant(club) do
        Dispensaciones::RecibirCajaDelivery.call(delivery: repartidor, club: club, receptor: admin)
      end

      expect(cobro.reload.caja_turno_id).to eq(caja_norte.id)
      expect(caja_norte.reload.total_efectivo_ars).to eq(8_000.0)
    end

    # Si no hay forma de saber dónde entró, el cobro se asienta igual y queda sin turno: la plata
    # entró al club, y eso no puede depender de que alguien haya abierto un mostrador.
    it 'con dos cajas abiertas y un receptor sin sede, se rinde igual pero sin turno' do
      abrir_caja!(norte,  hace: 3.hours.ago)
      abrir_caja!(centro, hace: 1.hour.ago)

      disp = dispensacion_con_envio
      cobro = ActsAsTenant.with_tenant(club) do
        Dispensaciones::RegistrarCobro.call(dispensacion: disp, club: club, usuario: repartidor,
                                            medio: 'efectivo', monto: 8_000, contexto: 'entrega').cobro
      end
      res = ActsAsTenant.with_tenant(club) do
        Dispensaciones::RecibirCajaDelivery.call(delivery: repartidor, club: club, receptor: admin)
      end

      expect(res).to be_ok
      expect(cobro.reload.rendido).to be(true)
      expect(cobro.caja_turno_id).to be_nil
    end
  end
end
