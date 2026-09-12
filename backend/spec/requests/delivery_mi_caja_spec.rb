require 'rails_helper'

# LO QUE EL REPARTIDOR LLEVA ENCIMA.
#
# El monto de una rendición lo pone el sistema —pedirle que se acuerde de lo que cobró en doce
# puertas es pedirle un error—, pero NUNCA se lo mostrábamos: rendía a ciegas, sin poder contar
# los billetes contra nada, y si el que recibía contaba distinto se enteraba al día siguiente con
# la diferencia anotada a su nombre.
RSpec.describe 'GET /rendiciones/mi_caja', type: :request do
  include AuthHelpers

  let(:club)  { create(:club, features: { 'produccion_dispensa' => true, 'delivery' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:juan)  { create(:user, :delivery, club: club, first_name: 'Juan') }
  let(:otro)  { create(:user, :delivery, club: club, first_name: 'Otro') }
  let(:sede)  { create(:sede, club: club, tipo: 'mixta') }
  let(:lote)  { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }

  let!(:stock) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 1_000, estado: 'asignado', disponibilidad: 'ambas', precio_sugerido_ars: 100)
    end
  end

  def json = JSON.parse(response.body)

  def entrega!(monto, medio: 'efectivo', de: nil, nombre: 'Rocío')
    ActsAsTenant.with_tenant(club) do
      pac = create(:paciente, club: club, nombre: nombre)
      d = Dispensacion.create!(paciente: pac, user: admin, stock: stock, sede: sede, cantidad: 5,
                               medio_pago: 'efectivo', aporte_socio_ars: monto,
                               fecha_dispensacion: Time.zone.today, con_envio: true,
                               delivery_id: (de || juan).id, direccion_envio: 'Falsa 123',
                               contacto_nombre: 'X')
      Dispensaciones::RegistrarCobro.call(dispensacion: d, club: club, usuario: (de || juan),
                                          medio: medio, monto: monto, contexto: 'entrega')
      d
    end
  end

  def mi_caja!(como)
    sign_in_as(como)
    get '/api/rendiciones/mi_caja', headers: auth_headers
    json
  end

  it 'suma el efectivo que cobró y todavía no rindió, con el detalle para contarlo' do
    entrega!(60_000, nombre: 'Rocío')
    entrega!(40_000, nombre: 'Santiago')

    body = mi_caja!(juan)

    expect(response).to have_http_status(:ok)
    expect(body['efectivo_ars']).to eq(100_000.0)
    expect(body['cobros'].map { |c| c['paciente'] }).to include(a_string_matching(/Rocío/), a_string_matching(/Santiago/))
    expect(body['cobros'].map { |c| c['monto_ars'] }).to match_array([60_000.0, 40_000.0])
  end

  # Ese es el número que va a declarar: si se calculara aparte, un día dirían distinto y el que
  # descubre la diferencia es él, contando billetes con alguien esperando.
  it 'es EXACTAMENTE lo que se declara al rendir' do
    entrega!(60_000)
    entrega!(40_000)
    body = mi_caja!(juan)

    sign_in_as(juan)
    post '/api/rendiciones', headers: auth_headers, params: { receptor_id: admin.id }

    expect(json['declarado_ars']).to eq(body['efectivo_ars'])
  end

  # Esa plata ya entró a la cuenta de la organización: sumarla sería pedirle billetes que no tiene.
  it 'lo cobrado por transferencia va aparte y no suma al efectivo' do
    entrega!(60_000)
    entrega!(12_500, medio: 'transferencia')

    body = mi_caja!(juan)

    expect(body['efectivo_ars']).to eq(60_000.0)
    expect(body['transferencias_ars']).to eq(12_500.0)
  end

  it 'no se mezcla con lo de otro repartidor' do
    entrega!(60_000)
    entrega!(90_000, de: otro)

    expect(mi_caja!(juan)['efectivo_ars']).to eq(60_000.0)
    expect(mi_caja!(otro)['efectivo_ars']).to eq(90_000.0)
  end

  it 'cuenta los paquetes que vuelven sin entregar, que van en la misma vuelta' do
    d = entrega!(60_000)
    d.update!(estado_envio: 'fallido', fallido_at: Time.current, motivo_fallo: 'nadie')

    expect(mi_caja!(juan)['paquetes_sin_entregar']).to eq(1)
  end

  it 'lo ya rendido deja de contarse' do
    entrega!(60_000)
    sign_in_as(juan)
    post '/api/rendiciones', headers: auth_headers, params: { receptor_id: admin.id }

    expect(mi_caja!(juan)['efectivo_ars']).to eq(0.0)
  end

  # Lo que quedó a su nombre de rendiciones anteriores lo dice la TARJETA de rendición con su
  # propio dato: viajaba también acá y no lo leía nadie. El campo que se calcula, se serializa y
  # nadie usa es de donde salen las divergencias — en este proyecto ya apareció tres veces.
  it 'no manda lo que ya dice la tarjeta de rendición' do
    entrega!(60_000)
    body = mi_caja!(juan)

    expect(body).not_to have_key('saldo_a_cuenta_ars')
  end

  it 'es del repartidor: nadie más la pide' do
    mi_caja!(admin)
    expect(response).to have_http_status(:forbidden)
  end

  # EL TRABAJO DE AHORA, no todo lo que repartió en su vida. `mis_paquetes` no filtraba por
  # estado: le mandaba TODOS los paquetes que le asignaron desde siempre, en la pantalla que más
  # abre y que iba a crecer para siempre.
  describe 'GET /dispensaciones/mis_paquetes' do
    it 'trae lo que está en la calle y no el historial entero' do
      pendiente = entrega!(10_000, nombre: 'Pendiente')
      viaje     = entrega!(20_000, nombre: 'EnViaje')
      fallido   = entrega!(30_000, nombre: 'Fallido')
      entregado = entrega!(40_000, nombre: 'Entregado')

      viaje.update!(estado_envio: 'en_viaje')
      fallido.update!(estado_envio: 'fallido', fallido_at: Time.current, motivo_fallo: 'nadie')
      entregado.update!(estado_envio: 'entregado', entregado_at: Time.current)

      sign_in_as(juan)
      get '/api/dispensaciones/mis_paquetes', headers: auth_headers

      ids = json['dispensaciones'].map { |d| d['id'] }
      expect(ids).to match_array([pendiente.id, viaje.id, fallido.id])
      expect(ids).not_to include(entregado.id)
    end
  end
end
