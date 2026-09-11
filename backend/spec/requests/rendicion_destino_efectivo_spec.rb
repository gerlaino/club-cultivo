require 'rails_helper'

# UNA RENDICIÓN ES UNA ENTREGA EN MANO: va dirigida a una persona, y cae en un cajón.
#
# El código no cumplía ninguna de las dos. `puedo_recibir` decía "cualquiera que no sea el
# repartidor", así que la rendición que el repartidor le estaba entregando al dispensador le
# aparecía con su botón al admin, al supervisor y a todos los dispensadores a la vez — y el que
# apretaba primero quedaba escrito como el que la recibió. Lo encontró Germán probando: rindió al
# dispensador y el botón le apareció al admin.
#
# Y la caja se DEDUCÍA de las sedes del que recibía: con un admin (que no tiene sede) y dos
# mostradores abiertos daba nil, el cobro se marcaba rendido igual y no entraba a ningún arqueo.
# Plata en el aire, en silencio.
#
# Ahora el destino lo dice una persona, y quién lo dice depende del rol:
#   · el DISPENSADOR no elige — cae en la caja de SU mostrador;
#   · ADMINISTRACIÓN elige — la caja de un mostrador abierto, o la organización (asiento y nada más).
RSpec.describe 'Dónde entra el efectivo de una rendición', type: :request do
  include AuthHelpers

  let(:club)  { create(:club, features: { 'produccion_dispensa' => true, 'delivery' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:juan)  { create(:user, :delivery, club: club, first_name: 'Juan') }
  let(:dana)  { create(:user, :dispensador, club: club, first_name: 'Dana') }
  let(:otro)  { create(:user, :dispensador, club: club, first_name: 'Otro') }
  let(:sede)  { create(:sede, club: club, tipo: 'social') }
  let(:lote)  { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }

  let!(:stock) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 1_000, estado: 'asignado', disponibilidad: 'ambas', precio_sugerido_ars: 100)
    end
  end

  # Juan cobró $100.000 en la puerta.
  before do
    ActsAsTenant.with_tenant(club) do
      d = Dispensacion.create!(paciente: create(:paciente, club: club), user: admin, stock: stock,
                               sede: sede, cantidad: 10, medio_pago: 'efectivo',
                               aporte_socio_ars: 100_000, fecha_dispensacion: Time.zone.today,
                               con_envio: true, delivery_id: juan.id,
                               direccion_envio: 'Falsa 123', contacto_nombre: 'X')
      Dispensaciones::RegistrarCobro.call(dispensacion: d, club: club, usuario: juan,
                                          medio: 'efectivo', monto: 100_000, contexto: 'entrega')
    end
  end

  def json = JSON.parse(response.body)

  def rendir_a!(quien)
    sign_in_as(juan)
    post '/api/rendiciones', headers: auth_headers, params: { receptor_id: quien.id }
    json['id']
  end

  def recibir!(id, como:, destino: nil, monto: nil)
    sign_in_as(como)
    post "/api/rendiciones/#{id}/recibir", headers: auth_headers,
         params: { monto_recibido_ars: monto, destino: destino }.compact
    json
  end

  describe 'la rendición es de quien la tiene que recibir' do
    it 'el admin NO puede recibir la que el repartidor le rindió al dispensador' do
      id   = rendir_a!(dana)
      body = recibir!(id, como: admin, destino: 'club')

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to include('Dana')
      expect(RendicionCaja.unscoped.find(id).estado).to eq('pendiente')
    end

    it 'ni otro dispensador que no es el destinatario' do
      id = rendir_a!(dana)
      recibir!(id, como: otro)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'y el botón sólo le aparece a esa persona' do
      rendir_a!(dana)

      sign_in_as(admin)
      get '/api/rendiciones', headers: auth_headers
      expect(json['rendiciones'].map { |r| r['puedo_recibir'] }).to all(be(false))

      sign_in_as(dana)
      get '/api/rendiciones', headers: auth_headers
      expect(json['rendiciones'].map { |r| r['puedo_recibir'] }).to all(be(true))
    end

    it 'al otro dispensador ni siquiera se la listamos' do
      rendir_a!(dana)

      sign_in_as(otro)
      get '/api/rendiciones', headers: auth_headers
      expect(json['rendiciones']).to be_empty
    end
  end

  describe 'el dispensador no elige: cae en la caja de su mostrador' do
    it 'entra a su caja abierta sin preguntarle nada' do
      turno = abrir_mostrador!(sede, usuario: admin, recibe: dana)
      caja  = turno.caja_turno
      antes = caja.efectivo_esperado_ars.to_d

      id = rendir_a!(dana)
      recibir!(id, como: dana)

      expect(response).to have_http_status(:ok)
      expect(caja.reload.efectivo_esperado_ars.to_d - antes).to eq(100_000)
      expect(Cobro.unscoped.where(rendicion_caja_id: id).pluck(:caja_turno_id)).to all(eq(caja.id))
    end

    it 'ni se le ofrece elegir' do
      abrir_mostrador!(sede, usuario: admin, recibe: dana)
      rendir_a!(dana)

      sign_in_as(dana)
      get '/api/rendiciones', headers: auth_headers
      expect(json['rendiciones'].first['elijo_destino']).to be(false)
      expect(json['cajas_abiertas']).to be_empty
    end

    it 'sin la caja abierta no recibe, y el mensaje dice qué hacer' do
      id   = rendir_a!(dana)
      body = recibir!(id, como: dana)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/Abrí la caja/i)
      expect(Cobro.unscoped.where(rendicion_caja_id: id).pluck(:rendido)).to all(be(false))
    end
  end

  describe 'administración elige' do
    it 'sin decir dónde, no se recibe' do
      id   = rendir_a!(admin)
      body = recibir!(id, como: admin)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/dónde entra el efectivo/i)
    end

    it 'eligiendo un mostrador, entra a esa caja' do
      turno = abrir_mostrador!(sede, usuario: admin, recibe: dana)
      caja  = turno.caja_turno
      antes = caja.efectivo_esperado_ars.to_d

      id = rendir_a!(admin)
      recibir!(id, como: admin, destino: sede.id)

      expect(response).to have_http_status(:ok)
      expect(caja.reload.efectivo_esperado_ars.to_d - antes).to eq(100_000)
    end

    # EL EFECTIVO ENTRA A UNA CAJA, Y SI SE LO LLEVA LO SACA DEL CAJÓN. Así son dos registros
    # —quién la recibió y quién se la llevó— en vez de plata asentada que ningún arqueo reclama
    # y que nadie tiene a su nombre. El retiro ya existe y se salda cuando la trae.
    it 'con una caja abierta NO puede mandarla a la organización' do
      abrir_mostrador!(sede, usuario: admin, recibe: dana)

      id   = rendir_a!(admin)
      body = recibir!(id, como: admin, destino: 'club')

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/tiene que entrar a una caja/i)
      expect(body['error']).to match(/sacalo del cajón/i)
    end

    # Sin cajón abierto no se traba: obligar ahí dejaría al repartidor volviéndose a su casa con
    # la recaudación, que es peor que un asiento sin arqueo.
    it 'sin ninguna caja abierta, se asienta igual y queda en la organización' do
      id = rendir_a!(admin)
      expect { recibir!(id, como: admin, destino: 'club') }
        .to change { MovimientoContable.unscoped.where(categoria: 'dispensacion').count }.by(1)

      expect(response).to have_http_status(:ok)
      expect(Cobro.unscoped.where(rendicion_caja_id: id).pluck(:caja_turno_id)).to all(be_nil)
    end

    it 'y se le ofrecen las cajas abiertas de SUS sedes' do
      abrir_mostrador!(sede, usuario: admin, recibe: dana)
      rendir_a!(admin)

      sign_in_as(admin)
      get '/api/rendiciones', headers: auth_headers
      expect(json['rendiciones'].first['elijo_destino']).to be(true)
      expect(json['cajas_abiertas'].map { |c| c['sede_id'] }).to eq([sede.id])
    end

    it 'no puede mandar el mostrador de una sede que no es suya' do
      otra = create(:sede, club: club, tipo: 'social')
      abrir_mostrador!(otra, usuario: admin, recibe: dana)
      admin.sedes_asignadas << sede   # queda limitado a la suya

      id   = rendir_a!(admin)
      body = recibir!(id, como: admin, destino: otra.id)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/no es de tus sedes/i)
    end

    it 'un mostrador con la caja cerrada tampoco: no hay cajón donde ponerla' do
      id   = rendir_a!(admin)
      body = recibir!(id, como: admin, destino: sede.id)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/no tiene la caja abierta/i)
    end
  end

  # LA OTRA PUERTA: "Recibir caja" desde la ficha del repartidor, la que usa el admin cuando el
  # repartidor se fue sin rendir. La misma plata no puede entrar distinto según por dónde pasó.
  describe 'desde la ficha del repartidor' do
    it 'con una caja abierta tampoco la manda a la organización' do
      abrir_mostrador!(sede, usuario: admin, recibe: dana)

      sign_in_as(admin)
      post "/api/usuarios/#{juan.id}/recibir_caja", headers: auth_headers, params: { destino: 'club' }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['error']).to match(/tiene que entrar a una caja/i)
      expect(Cobro.unscoped.where(created_by_id: juan.id).pluck(:rendido)).to all(be(false))
    end

    it 'eligiendo el mostrador, entra a esa caja' do
      turno = abrir_mostrador!(sede, usuario: admin, recibe: dana)
      caja  = turno.caja_turno
      antes = caja.efectivo_esperado_ars.to_d

      sign_in_as(admin)
      post "/api/usuarios/#{juan.id}/recibir_caja", headers: auth_headers, params: { destino: sede.id }

      expect(response).to have_http_status(:ok)
      expect(caja.reload.efectivo_esperado_ars.to_d - antes).to eq(100_000)
    end

    # La pantalla tiene que poder ofrecer las cajas sin salir a buscarlas por otra puerta.
    it 'la ficha trae las cajas donde puede caer' do
      abrir_mostrador!(sede, usuario: admin, recibe: dana)

      sign_in_as(admin)
      get "/api/usuarios/#{juan.id}/stats", headers: auth_headers

      expect(json['cajas_abiertas'].map { |c| c['sede_id'] }).to eq([sede.id])
      expect(json.dig('caja_delivery', 'efectivo_en_mano')).to eq(100_000.0)
    end
  end
end