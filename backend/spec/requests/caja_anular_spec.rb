require 'rails_helper'

# AC (Germán): "abrí caja, pero me arrepentí, quiero deshacer lo que hice".
#
# No había forma. Y la salida obvia era peor que el problema: cerrarla con $0 contado genera un
# FALTANTE de arqueo por todo el fondo, o sea un egreso inventado en el libro por una caja que
# nunca operó.
#
# Anular no es cerrar. Abrir no genera asiento —el fondo es plata del club que cambia de lugar—
# así que deshacerlo tampoco tiene nada que revertir en contabilidad.
#
# La línea es el MOVIMIENTO: una caja sin cobros ni salidas se anula; con plata adentro se cierra
# con su arqueo, porque ahí sí pasó algo que hay que explicar.
#
# Y ABRIR ES UN SOLO GESTO QUE CREA DOS COSAS —la caja de plata y el turno de mercadería—, así que
# deshacerlo tiene que deshacer las dos. La MESA no se toca: es del mostrador y es permanente, el
# producto sigue físicamente ahí.
RSpec.describe 'Anular una caja abierta por error', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:ana)   { create(:user, :dispensador, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'social') }

  def abrir!(monto: 100_000, como: admin)
    sign_in_as(como)
    post "/api/sedes/#{sede.id}/mostrador/abrir", headers: auth_headers,
         params: { efectivo_contado_ars: monto }
    JSON.parse(response.body)
  end

  def anular!(id, como: admin, motivo: 'me equivoqué de sede')
    sign_in_as(como)
    post "/api/sedes/#{sede.id}/caja/#{id}/anular", headers: auth_headers, params: { motivo: motivo }
  end

  # Un frasco sobre la mesa, cargado por administración como en la vida real.
  def cargar_la_mesa!(cantidad: 100)
    ActsAsTenant.with_tenant(club) do
      lote  = create(:lote, club: club, sala: create(:sala, club: club, sede: sede))
      stock = create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca',
                             cantidad: 500, precio_sugerido_ars: 100)
      res = Mostradores::Cargar.call(mostrador: sede.mostrador!, usuario: admin,
                                     cambios: [{ stock_id: stock.id, cantidad: cantidad }],
                                     motivo: 'carga de la mañana')
      raise res.error unless res.ok?

      stock
    end
  end

  it 'una caja recién abierta se anula y libera el mostrador' do
    caja = abrir!

    anular!(caja['caja_turno_id'])

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['estado']).to eq('anulada')
    # Y se puede volver a abrir: el índice único sólo reserva el mostrador para las activas.
    abrir!(monto: 50_000)
    expect(response).to have_http_status(:created)
  end

  # Lo que se rompía antes de arreglarlo: anular la caja dejaba el TURNO abierto apuntando a una
  # caja anulada. El mostrador no se podía volver a abrir —decía que ya había uno— ni cerrar —el
  # cierre le pedía el arqueo a una caja que ya no estaba—: la sede quedaba sin poder dispensar.
  it 'el turno del mostrador se deshace con ella, no queda uno abierto colgado' do
    caja = abrir!

    anular!(caja['caja_turno_id'])

    expect(TurnoMostrador.where(club_id: club.id).abiertos.count).to eq(0)
    expect(TurnoMostrador.where(club_id: club.id, id: caja['id']).exists?).to be(false)
  end

  # LA MESA NO SE DESARMA. El contenido del mostrador es permanente y es del mostrador, no del
  # turno: el producto está físicamente arriba, y que alguien se haya equivocado al abrir la caja
  # no lo mueve de lugar.
  it 'lo que está sobre la mesa se queda donde está' do
    stock = cargar_la_mesa!(cantidad: 100)
    caja  = abrir!

    anular!(caja['caja_turno_id'])

    expect(mesa_de(sede)[stock.id]).to eq(100.0)
  end

  # Lo importante: anular NO deja rastro en el libro, porque abrir tampoco lo dejaba.
  it 'no genera ningún movimiento contable' do
    caja = abrir!

    expect { anular!(caja['caja_turno_id']) }
      .not_to change { MovimientoContable.where(club_id: club.id).count }
  end

  it 'queda quién la anuló y por qué' do
    caja = abrir!

    anular!(caja['caja_turno_id'], motivo: 'puse mal el fondo')
    cuerpo = JSON.parse(response.body)

    expect(cuerpo['cerrada_por']).to eq(admin.nombre_completo)
    expect(cuerpo['notas']).to eq('puse mal el fondo')
  end

  describe 'con plata adentro' do
    let(:dispensacion) do
      ActsAsTenant.with_tenant(club) do
        lote  = create(:lote, club: club, sala: create(:sala, club: club, sede: sede))
        stock = create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca',
                               cantidad: 500, precio_sugerido_ars: 100)
        Dispensacion.create!(paciente: create(:paciente, club: club), user: admin, stock: stock,
                             sede: sede, cantidad: 5, medio_pago: 'efectivo',
                             aporte_socio_ars: 5_000, fecha_dispensacion: Time.zone.today)
      end
    end

    it 'ya no se anula: se cierra con su arqueo' do
      caja = abrir!
      ActsAsTenant.with_tenant(club) do
        Dispensaciones::RegistrarCobro.call(dispensacion: dispensacion, club: club, usuario: admin,
                                            medio: 'efectivo', monto: 5_000)
      end

      anular!(caja['caja_turno_id'])

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/movimientos/i)
    end
  end

  # Una dispensa a cuenta corriente no pone un peso en el cajón, así que la caja sigue siendo
  # "anulable" mirando sólo la plata. Pero el turno ya atendió a alguien: eso no es una apertura
  # equivocada, es una jornada que pasó, y se cierra con su arqueo como cualquier otra.
  it 'si ya se dispensó, no es una apertura equivocada: hay que cerrar con arqueo' do
    stock = cargar_la_mesa!(cantidad: 100)
    caja  = abrir!(como: ana)

    ActsAsTenant.with_tenant(club) do
      pac = create(:paciente, club: club)
      pac.create_cuenta_corriente!(club: club, saldo_disponible: 0, limite_credito: 50_000)
      Dispensacion.create!(paciente: pac, user: ana, stock: stock, sede: sede, cantidad: 5,
                           medio_pago: 'cuenta_corriente', aporte_socio_ars: 500,
                           fecha_dispensacion: Time.zone.today)
    end

    anular!(caja['caja_turno_id'])

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['error']).to match(/arqueo/i)
    expect(TurnoMostrador.where(club_id: club.id).abiertos.count).to eq(1)
  end

  # No se muestra en pantalla —una apertura anulada no es un turno y no tiene nada que contar—
  # pero el rastro tiene que existir para poder dárselo al cliente si lo pide.
  it 'queda en el audit log quién la anuló, aunque no se muestre en ningún lado' do
    caja = abrir!

    anular!(caja['caja_turno_id'], motivo: 'me equivoqué de sede')

    rastro = ActsAsTenant.without_tenant do
      Auditoria.where(club_id: club.id, auditable_type: 'CajaTurno', auditable_id: caja['caja_turno_id'])
               .order(:created_at).last
    end

    expect(rastro).to be_present
    expect(rastro.user_id).to eq(admin.id)
    expect(rastro.cambios.to_s).to include('anulada')
  end

  it 'el dispensador no puede anularla: la abre y la deshace quien responde por la plata' do
    caja = abrir!

    anular!(caja['caja_turno_id'], como: ana)

    expect(response).to have_http_status(:forbidden)
  end
end
