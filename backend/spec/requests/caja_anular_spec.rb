require 'rails_helper'

# AC (Germán): "abrí caja, confirmé, pero me arrepentí, quiero deshacer lo que hice".
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
RSpec.describe 'Anular una caja abierta por error', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:ana)   { create(:user, :dispensador, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'social') }

  def abrir!(monto: 100_000)
    sign_in_as(admin)
    post "/api/sedes/#{sede.id}/caja/abrir", headers: auth_headers, params: { monto_inicial_ars: monto }
    JSON.parse(response.body)
  end

  def anular!(id, como: admin, motivo: 'me equivoqué de sede')
    sign_in_as(como)
    post "/api/sedes/#{sede.id}/caja/#{id}/anular", headers: auth_headers, params: { motivo: motivo }
  end

  it 'una caja recién abierta se anula y libera el mostrador' do
    caja = abrir!

    anular!(caja['id'])

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['estado']).to eq('anulada')
    # Y se puede volver a abrir: el índice único sólo reserva el mostrador para las activas.
    abrir!(monto: 50_000)
    expect(response).to have_http_status(:created)
  end

  it 'se puede anular aunque ya hayan confirmado el fondo' do
    caja = abrir!
    sign_in_as(ana)
    post "/api/sedes/#{sede.id}/caja/#{caja['id']}/confirmar_apertura", headers: auth_headers

    anular!(caja['id'])

    expect(JSON.parse(response.body)['estado']).to eq('anulada')
  end

  # Lo importante: anular NO deja rastro en el libro, porque abrir tampoco lo dejaba.
  it 'no genera ningún movimiento contable' do
    caja = abrir!

    expect { anular!(caja['id']) }.not_to change { MovimientoContable.where(club_id: club.id).count }
  end

  it 'queda quién la anuló y por qué' do
    caja = abrir!

    anular!(caja['id'], motivo: 'puse mal el fondo')
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

      anular!(caja['id'])

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/movimientos/i)
    end
  end

  # No se muestra en pantalla —una apertura anulada no es un turno y no tiene nada que contar—
  # pero el rastro tiene que existir para poder dárselo al cliente si lo pide.
  it 'queda en el audit log quién la anuló, aunque no se muestre en ningún lado' do
    caja = abrir!

    anular!(caja['id'], motivo: 'me equivoqué de sede')

    rastro = ActsAsTenant.without_tenant do
      Auditoria.where(club_id: club.id, auditable_type: 'CajaTurno', auditable_id: caja['id'])
               .order(:created_at).last
    end

    expect(rastro).to be_present
    expect(rastro.user_id).to eq(admin.id)
    expect(rastro.cambios.to_s).to include('anulada')
  end

  it 'el dispensador no puede anularla: la abre y la deshace quien responde por la plata' do
    caja = abrir!

    anular!(caja['id'], como: ana)

    expect(response).to have_http_status(:forbidden)
  end
end
