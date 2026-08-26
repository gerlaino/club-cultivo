require 'rails_helper'

# El cruce de los dos roles que arrancan la semana que viene: el repartidor cobra en la PUERTA y
# el arqueo lo hace el mostrador.
#
# Esa plata está en el bolsillo del repartidor, no en el cajón. Si se engancha a la caja del
# mostrador cuando se cobra, el arqueo espera un efectivo que todavía no llegó y el turno cierra
# con un faltante que no existe — y quien lo paga es el que está atendiendo.
#
# Entra cuando se RINDE la caja, que es cuando la plata aparece de verdad. Es la misma línea que
# ya trazaba `diferido_a_rendicion?` para el asiento contable.
RSpec.describe 'El efectivo del repartidor y la caja del mostrador', type: :request do
  include AuthHelpers

  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:repartidor) { create(:user, :delivery, club: club) }
  let(:sede)     { create(:sede, club: club) }

  let!(:caja) do
    ActsAsTenant.with_tenant(club) do
      CajaTurno.create!(club: club, sede: sede, punto: sede, abierta_por: admin,
                        monto_inicial_ars: 10_000, abierta_at: Time.current, estado: 'abierta')
    end
  end

  let(:dispensacion) do
    ActsAsTenant.with_tenant(club) do
      lote  = create(:lote, club: club, sala: create(:sala, club: club, sede: sede))
      stock = create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca',
                             cantidad: 500, precio_sugerido_ars: 100)
      pac = create(:paciente, club: club)
      d = Dispensacion.create!(paciente: pac, user: admin, stock: stock, sede: sede, cantidad: 5,
                               medio_pago: 'efectivo', aporte_socio_ars: 8_000,
                               fecha_dispensacion: Time.zone.today, con_envio: true,
                               delivery_id: repartidor.id,
                               direccion_envio: 'Falsa 123', contacto_nombre: 'Ana')
      d
    end
  end

  def cobrar_en_la_puerta!(monto: 8_000)
    ActsAsTenant.with_tenant(club) do
      Dispensaciones::RegistrarCobro.call(dispensacion: dispensacion, club: club,
                                          usuario: repartidor, medio: 'efectivo',
                                          monto: monto, contexto: 'entrega')
    end
  end

  it 'lo que cobra el repartidor NO entra en el arqueo del mostrador' do
    res = cobrar_en_la_puerta!
    expect(res.ok?).to be(true), res.error

    expect(res.cobro.caja_turno_id).to be_nil
    expect(caja.reload.total_efectivo_ars).to eq(0.0)
    # El fondo y nada más: el turno no tiene que esperar plata que está en la calle.
    expect(caja.efectivo_esperado_ars).to eq(10_000.0)
  end

  it 'entra cuando se rinde la caja, que es cuando la plata llega' do
    cobro = cobrar_en_la_puerta!.cobro

    ActsAsTenant.with_tenant(club) do
      Dispensaciones::RecibirCajaDelivery.call(delivery: repartidor, club: club, receptor: admin)
    end

    expect(cobro.reload.caja_turno_id).to eq(caja.id)
    expect(cobro.rendido).to be(true)
    expect(caja.reload.total_efectivo_ars).to eq(8_000.0)
    expect(caja.efectivo_esperado_ars).to eq(18_000.0)
  end

  # Si entrega un admin, la plata va directo al cajón: ahí sí se engancha en el acto.
  it 'si el que entrega es el admin, entra en el momento' do
    res = ActsAsTenant.with_tenant(club) do
      Dispensaciones::RegistrarCobro.call(dispensacion: dispensacion, club: club, usuario: admin,
                                          medio: 'efectivo', monto: 8_000, contexto: 'entrega')
    end

    expect(res.cobro.caja_turno_id).to eq(caja.id)
    expect(caja.reload.total_efectivo_ars).to eq(8_000.0)
  end

  # Un cobro del mostrador sí es plata en el cajón, en el acto.
  it 'lo cobrado en el mostrador entra en el momento' do
    res = ActsAsTenant.with_tenant(club) do
      Dispensaciones::RegistrarCobro.call(dispensacion: dispensacion, club: club, usuario: admin,
                                          medio: 'efectivo', monto: 3_000, contexto: 'creacion')
    end

    expect(res.cobro.caja_turno_id).to eq(caja.id)
  end
end
