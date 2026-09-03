require 'rails_helper'

# La entrega de la recaudación del repartidor, con las dos personas adentro.
#
# Antes era unilateral: el receptor apretaba un botón y el sistema daba por rendido todo. Dos
# agujeros — nadie CONTABA la plata (si traía menos, el sistema no se enteraba) y el repartidor
# no tenía forma de dejar constancia de que la entregó.
#
# LA PLATA NUNCA QUEDA EN EL AIRE: es efectivo, el que cuenta es el que la tiene en la mano y ese
# número entra al cajón. No hay estado "en disputa". Lo que queda pendiente si hubo ajuste es la
# CONFORMIDAD del repartidor, que es constancia y no candado.
RSpec.describe 'Rendir la caja del repartidor', type: :request do
  include AuthHelpers

  let(:club)  { create(:club, features: { 'produccion_dispensa' => true, 'delivery' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:juan)  { create(:user, :delivery, club: club, first_name: 'Juan') }
  let(:sede)  { create(:sede, club: club, tipo: 'social') }
  let(:lote)  { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }

  let!(:stock) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 1_000, estado: 'asignado', disponibilidad: 'ambas', precio_sugerido_ars: 100)
    end
  end

  # Dos entregas cobradas en la puerta por Juan: $60.000 y $40.000.
  before do
    ActsAsTenant.with_tenant(club) do
      [60_000, 40_000].each do |monto|
        d = Dispensacion.create!(paciente: create(:paciente, club: club), user: admin, stock: stock,
                                 sede: sede, cantidad: 10, medio_pago: 'efectivo',
                                 aporte_socio_ars: monto, fecha_dispensacion: Time.zone.today,
                                 con_envio: true, delivery_id: juan.id,
                                 direccion_envio: 'Falsa 123', contacto_nombre: 'X')
        Dispensaciones::RegistrarCobro.call(dispensacion: d, club: club, usuario: juan,
                                            medio: 'efectivo', monto: monto, contexto: 'entrega')
      end
    end
  end

  def rendir!(a: admin, como: juan)
    sign_in_as(como)
    post '/api/rendiciones', headers: auth_headers, params: { receptor_id: a.id }
    JSON.parse(response.body)
  end

  def recibir!(id, monto: nil, motivo: nil, como: admin)
    sign_in_as(como)
    post "/api/rendiciones/#{id}/recibir", headers: auth_headers,
         params: { monto_recibido_ars: monto, motivo: motivo }.compact
    JSON.parse(response.body)
  end

  describe 'el repartidor rinde y elige a quién' do
    it 'el monto lo pone el sistema, no él' do
      body = rendir!

      expect(response).to have_http_status(:created)
      expect(body['declarado_ars']).to eq(100_000.0)
      expect(body['cobros']).to eq(2)
      expect(body['estado']).to eq('pendiente')
      expect(body['receptor']).to eq(admin.nombre_completo)
    end

    it 'no se rinde a sí mismo' do
      body = rendir!(a: juan)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/a vos mismo/i)
    end

    # Dos rendiciones abiertas partirían la misma plata en dos.
    it 'no se rinde dos veces sin que la reciban' do
      rendir!
      body = rendir!

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/esperando que la reciban/i)
    end

    it 'sin efectivo pendiente no hay nada que rendir' do
      rendir!
      recibir!(RendicionCaja.unscoped.last.id)
      body = rendir!

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/no tenés efectivo ni paquetes/i)
    end
  end

  describe 'el receptor cuenta y recibe' do
    let!(:rendicion) { rendir!['id'] }

    it 'si coincide, entra completo y no hay nada que conformar' do
      body = recibir!(rendicion)

      expect(response).to have_http_status(:ok)
      expect(body['estado']).to eq('recibida')
      expect(body['recibido_ars']).to eq(100_000.0)
      expect(body['conforme']).to be_nil
      expect(Cobro.unscoped.where(rendicion_caja_id: rendicion).pluck(:rendido)).to all(be(true))
    end

    it 'los ingresos se asientan al recibir, no al cobrar en la puerta' do
      expect { recibir!(rendicion) }
        .to change { MovimientoContable.unscoped.where(categoria: 'dispensacion').count }.by(2)
    end

    # El caso que motivó todo: trae $80.000 de los $100.000 que cobró.
    it 'si trae de menos, entra lo contado y la diferencia queda A NOMBRE SUYO' do
      body = recibir!(rendicion, monto: 80_000, motivo: 'me quedo 20 a cuenta de sueldo')

      expect(response).to have_http_status(:ok)
      expect(body['recibido_ars']).to eq(80_000.0)
      expect(body['diferencia_ars']).to eq(-20_000.0)

      mov = MovimientoContable.unscoped.where(categoria: 'a_cuenta_repartidor').last
      expect(mov.monto_ars.to_f).to eq(20_000.0)
      # Ajuste, no egreso: esa plata existe y está con una persona. No es una pérdida del club.
      expect(mov.tipo).to eq('ajuste')
      expect(mov.retirado_por_id).to eq(juan.id)
      expect(mov.descripcion).to match(/a cuenta de juan/i)
    end

    # El ingreso se asienta COMPLETO: el paciente pagó esa plata. Lo que falta no es menos venta.
    it 'traer de menos no baja la venta' do
      recibir!(rendicion, monto: 80_000, motivo: 'faltaron 20')

      expect(MovimientoContable.unscoped.where(categoria: 'dispensacion').sum(:monto_ars).to_f)
        .to eq(100_000.0)
    end

    it 'si trae de menos y no escribe el motivo, no se recibe' do
      body = recibir!(rendicion, monto: 80_000)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/escribí el motivo/i)
      expect(RendicionCaja.unscoped.find(rendicion)).to be_pendiente
    end

    # Un ajuste para ARRIBA taparía un cobro que no se cargó, y esa dispensa quedaría figurando
    # impaga para siempre.
    it 'no se puede ajustar hacia arriba' do
      body = recibir!(rendicion, monto: 120_000, motivo: 'trajo de más')

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/cargalo en su dispensa/i)
    end

    it 'el repartidor no se recibe su propia rendición' do
      body = recibir!(rendicion, como: juan)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/tu propia rendición/i)
    end
  end

  # La plata YA ENTRÓ. Esto es constancia de si el repartidor estuvo de acuerdo, no un candado.
  describe 'la conformidad del repartidor' do
    let!(:rendicion) { rendir!['id'] }

    before { recibir!(rendicion, monto: 80_000, motivo: 'faltaron 20') }

    it 'queda pendiente hasta que él diga algo' do
      expect(RendicionCaja.unscoped.find(rendicion).conforme).to be(false)

      sign_in_as(admin)
      get '/api/rendiciones', headers: auth_headers
      expect(JSON.parse(response.body)['sin_conformar']).to eq(1)
    end

    it 'la conforma y sale de la bandeja' do
      sign_in_as(juan)
      post "/api/rendiciones/#{rendicion}/conformar", headers: auth_headers, params: { conforme: true }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['conforme']).to be(true)
    end

    # Que no esté de acuerdo NO devuelve la plata ni reabre nada: queda escrito y se habla.
    it 'si no está de acuerdo, queda escrito y la plata no se mueve' do
      sign_in_as(juan)
      post "/api/rendiciones/#{rendicion}/conformar", headers: auth_headers,
           params: { conforme: false, notas: 'yo entregué los 100' }

      r = RendicionCaja.unscoped.find(rendicion)
      expect(r.conforme).to be(false)
      expect(r.motivo_ajuste).to match(/repartidor: yo entregué los 100/)
      expect(r).to be_recibida
      expect(r.monto_recibido_ars.to_f).to eq(80_000.0)
    end

    it 'sólo el repartidor conforma lo suyo' do
      sign_in_as(admin)
      post "/api/rendiciones/#{rendicion}/conformar", headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/sólo el repartidor/i)
    end
  end

  # El producto que vuelve sin entregar entra por la misma rendición.
  describe 'los paquetes que vuelven' do
    let!(:fallida) do
      ActsAsTenant.with_tenant(club) do
        d = Dispensacion.create!(paciente: create(:paciente, club: club), user: admin, stock: stock,
                                 sede: sede, cantidad: 25, medio_pago: 'efectivo',
                                 aporte_socio_ars: 2_500, fecha_dispensacion: Time.zone.today,
                                 con_envio: true, delivery_id: juan.id,
                                 direccion_envio: 'Falsa 456', contacto_nombre: 'Y')
        d.update!(estado_envio: 'fallido', motivo_fallo: 'no había nadie', fallido_at: Time.current)
        d
      end
    end

    it 'la rendición los muestra, con qué son y por qué volvieron' do
      body = rendir!
      p1 = body['devoluciones'].first

      expect(body['devoluciones'].size).to eq(1)
      expect(p1['id']).to eq(fallida.id)
      expect(p1['cantidad']).to eq(25.0)
      expect(p1['motivo_fallo']).to eq('no había nadie')
    end

    # TODO paquete que vuelve se desarma: es una decisión de CALIDAD, no de inventario. Uno que
    # estuvo en la calle no se guarda armado esperando otro intento — cuando se despache de nuevo
    # se arma en el momento, y para entonces puede haber cambiado hasta la forma de entrega.
    it 'se desarman TODOS al recibir: no se elige' do
      id = rendir!['id']
      recibir!(id)

      expect(fallida.reload.estado_envio).to eq('cancelada')
      expect(stock.reload.cantidad.to_f).to eq(980.0) # 955 + los 25 que volvieron
    end

    # Si el gramo volviera al depósito, quien atiende no lo tendría para entregárselo al próximo
    # que lo pida, con el paquete ahí adelante. Sube a la mesa Y se le hace lugar si no estaba.
    it 'y SUBE A LA MESA aunque ese producto no estuviera arriba' do
      abrir_mostrador!(sede, usuario: admin, recibe: create(:user, :dispensador, club: club))
      # La mesa arranca sin este stock: se lo saca para que la prueba sea la de verdad.
      ActsAsTenant.with_tenant(club) do
        Mostradores::Cargar.call(mostrador: sede.mostrador!, usuario: admin, motivo: 'lo bajo',
                                 cambios: [{ stock_id: stock.id, cantidad: 0 }])
      end
      expect(mesa_de(sede)[stock.id]).to be_nil

      id = rendir!['id']
      recibir!(id)

      expect(mesa_de(sede)[stock.id]).to eq(25.0)
      mov = MostradorMovimiento.unscoped.recientes.first
      expect(mov.tipo).to eq('devolucion')
      expect(mov.motivo).to match(/Volvió de la dispensación/)
    end

    # Y el mostrador ya no depende de que haya alguien atendiendo: el paquete vuelve a las once
    # de la noche y el producto queda sobre la mesa igual, listo para mañana.
    it 'aunque la caja esté cerrada' do
      turno = abrir_mostrador!(sede, usuario: admin, recibe: create(:user, :dispensador, club: club))
      ActsAsTenant.with_tenant(club) do
        Mostradores::Cargar.call(mostrador: sede.mostrador!, usuario: admin, motivo: 'lo bajo',
                                 cambios: [{ stock_id: stock.id, cantidad: 0 }])
        Mostradores::CerrarCaja.call(turno: turno, usuario: admin, efectivo_contado_ars: 0,
                                     conteos: sede.mostrador!.sobre_la_mesa.map { |mi|
                                       { stock_id: mi.stock_id, contado: mi.cantidad }
                                     })
      end

      recibir!(rendir!['id'])

      expect(mesa_de(sede)[stock.id]).to eq(25.0)
    end

    it 'sólo se desarman los del repartidor que rinde' do
      otro = create(:user, :delivery, club: club)
      ajena = ActsAsTenant.with_tenant(club) do
        d = Dispensacion.create!(paciente: create(:paciente, club: club), user: admin, stock: stock,
                                 sede: sede, cantidad: 5, medio_pago: 'efectivo',
                                 aporte_socio_ars: 500, fecha_dispensacion: Time.zone.today,
                                 con_envio: true, delivery_id: otro.id,
                                 direccion_envio: 'Falsa 789', contacto_nombre: 'Z')
        d.update!(estado_envio: 'fallido', fallido_at: Time.current, motivo_fallo: 'x')
        d
      end

      recibir!(rendir!['id'])

      expect(ajena.reload.estado_envio).to eq('fallido')
    end

    # El reintento del MISMO viaje sigue existiendo: falla a las 18 y vuelve a intentar a las 19
    # sin pasar por la base. Ahí el paquete nunca volvió, así que no se desarma.
    it 'reprogramar sigue andando mientras el paquete no vuelva' do
      sign_in_as(admin)
      patch "/api/dispensaciones/#{fallida.id}/reprogramar", headers: auth_headers,
            params: { motivo: 'vuelve a intentar a las 19' }

      expect(response).to have_http_status(:ok)
      expect(fallida.reload.estado_envio).to eq('pendiente')
      expect(stock.reload.cantidad.to_f).to eq(955.0) # sigue afuera: no volvió
    end
  end

  # Sin verlo acumulado, cada faltante parece un caso aislado y nadie nota que van seis seguidos.
  describe 'lo que el repartidor tiene del club, en su ficha' do
    it 'suma todo lo que se quedó, rendición por rendición' do
      2.times do
        ActsAsTenant.with_tenant(club) do
          d = Dispensacion.create!(paciente: create(:paciente, club: club), user: admin,
                                   stock: stock, sede: sede, cantidad: 5, medio_pago: 'efectivo',
                                   aporte_socio_ars: 30_000, fecha_dispensacion: Time.zone.today,
                                   con_envio: true, delivery_id: juan.id,
                                   direccion_envio: 'F 1', contacto_nombre: 'A')
          Dispensaciones::RegistrarCobro.call(dispensacion: d, club: club, usuario: juan,
                                              medio: 'efectivo', monto: 30_000, contexto: 'entrega')
        end
        id = rendir!['id']
        recibir!(id, monto: RendicionCaja.unscoped.find(id).monto_declarado_ars - 5_000,
                     motivo: 'se quedó 5')
      end

      sign_in_as(admin)
      get "/api/usuarios/#{juan.id}/stats", headers: auth_headers
      a_cuenta = JSON.parse(response.body)['a_cuenta']

      expect(a_cuenta['total_ars']).to eq(10_000.0)
      expect(a_cuenta['veces']).to eq(2)
      expect(a_cuenta['detalle'].first['descripcion']).to match(/a cuenta de juan/i)
    end

    it 'quien no debe nada, no tiene nada acumulado' do
      sign_in_as(admin)
      get "/api/usuarios/#{juan.id}/stats", headers: auth_headers

      expect(JSON.parse(response.body)['a_cuenta']['total_ars']).to eq(0.0)
    end
  end

  # La puerta vieja (el admin recibe sin que el repartidor haya rendido) tiene que seguir andando
  # y pasar por el mismo modelo del hecho: dos formas distintas de que la plata entre al cajón es
  # cómo dejan de coincidir.
  describe 'cuando el repartidor se fue sin rendir' do
    it 'el admin recibe igual, y queda la misma rendición' do
      sign_in_as(admin)
      post "/api/usuarios/#{juan.id}/recibir_caja", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['recibido_ars']).to eq(100_000.0)
      r = RendicionCaja.unscoped.last
      expect(r).to be_recibida
      expect(r.delivery_id).to eq(juan.id)
      expect(r.receptor_id).to eq(admin.id)
    end
  end
end
