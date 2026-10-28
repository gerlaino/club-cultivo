require 'rails_helper'

# «RESERVAR» DESDE EL PORTAL (Germán, 28-oct-2026): el catálogo ES Reservar.
#
# AC:
# - el paciente elige la sede y si retira HOY o MAÑANA; nunca más allá;
# - pide sólo lo que ve en el catálogo de esa sede (la mesa, genéticas publicadas);
# - el pedido queda «esperando confirmación» y NO aparta nada hasta que admin o supervisor lo
#   confirma; el rechazo lleva motivo y el paciente lo ve;
# - nunca le dice cuánto hay; UNA RESERVA POR DÍA (una para hoy y otra para mañana, no dos el mismo
#   día); cancela el suyo mientras nadie lo confirmó;
# - el dispensador no ve los pedidos sin confirmar; nada cruza de organización.
RSpec.describe 'Portal — Reservar', type: :request do
  include AuthHelpers

  let(:club)  { create(:club, vista_paciente_activa: true, features: { 'produccion_dispensa' => true, 'vista_paciente' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:supervisor)  { create(:user, club: club, role: 'supervisor') }
  let(:dispensador) { create(:user, :dispensador, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin, nombre: 'Sede Centro', tipo: 'mixta') }
  let(:otra_sede) { create(:sede, club: club, created_by: admin, nombre: 'Sede Norte', tipo: 'mixta') }
  let(:visible) { create(:genetica, club: club, nombre: 'Northern Lights', visible_paciente: true) }
  let(:oculta)  { create(:genetica, club: club, nombre: 'Secreta', visible_paciente: false) }

  def stock!(genetica, en: sede, precio: 1000)
    Stock.create!(sede: en, genetica: genetica, origen: 'compra_externa', proveedor: 'X', forma_producto: 'flor_seca',
                  unidad: 'g', cantidad: 500, precio_sugerido_ars: precio)
  end

  def a_la_mesa!(stock, gramos, en: sede)
    Mostradores::Cargar.call(mostrador: en.mostrador!, usuario: admin, motivo: 'carga', cambios: [{ stock_id: stock.id, cantidad: gramos }])
  end

  def cuenta_de(paciente)
    u = Pacientes::Acceso.crear!(paciente).user
    u.update!(password: AuthHelpers::DEFAULT_PASSWORD, password_confirmation: AuthHelpers::DEFAULT_PASSWORD)
    u
  end

  let(:paciente) { create(:paciente, club: club, created_by: admin, aprobado_at: Time.current) }
  let(:cuenta)   { cuenta_de(paciente) }
  let(:nl)       { stock!(visible).tap { |s| a_la_mesa!(s, 100) } }

  def hoy    = Time.zone.today
  def json   = JSON.parse(response.body)

  def pedir(items:, fecha: hoy, sede_id: sede.id, como: cuenta)
    sign_in_as(como)
    post '/api/portal/reservas', params: { sede_id: sede_id, fecha: fecha.iso8601, items: items }, as: :json
  end

  def catalogo_de_hoy
    get '/api/portal/catalogo'
    json['data'].find { |s| s['sede_id'] == sede.id }['productos'].first
  end

  describe 'pedir' do
    it 'para hoy: queda esperando confirmación y NO aparta nada de la mesa' do
      libre_antes = nl.libre_en_mostrador(sede.id)

      pedir(items: [{ stock_id: nl.id, cantidad: 10 }])

      expect(response).to have_http_status(:created), response.body
      expect(json['data']).to include('estado' => 'solicitada', 'sede' => 'Sede Centro', 'total_estimado' => 10_000.0)
      reserva = Reserva.find(json['data']['id'])
      expect(reserva).to have_attributes(origen: 'portal', user_id: nil, fecha_entrega_estimada: hoy)
      expect(nl.reload.libre_en_mostrador(sede.id)).to eq(libre_antes)
    end

    it 'para mañana también' do
      pedir(items: [{ stock_id: nl.id, cantidad: 10 }], fecha: hoy + 1)
      expect(response).to have_http_status(:created), response.body
    end

    it 'pasado mañana no: sólo hoy o mañana' do
      pedir(items: [{ stock_id: nl.id, cantidad: 10 }], fecha: hoy + 2)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['error']).to include('hoy o mañana')
    end

    it 'para ayer tampoco' do
      pedir(items: [{ stock_id: nl.id, cantidad: 10 }], fecha: hoy - 1)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'avisa a admin y a supervisor, que son quienes confirman' do
      pedir(items: [{ stock_id: nl.id, cantidad: 10 }])
      expect(AlertaInterna.where(tipo: 'reserva_solicitada').pluck(:destinada_a_role)).to contain_exactly('admin', 'supervisor')
    end

    it 'de la sede que eligió: un producto de la mesa de OTRA sede no se pide' do
      del_norte = stock!(visible, en: otra_sede).tap { |s| a_la_mesa!(s, 100, en: otra_sede) }

      pedir(items: [{ stock_id: del_norte.id, cantidad: 10 }], sede_id: sede.id)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Reserva.count).to eq(0)
    end

    it 'de varios productos, si SÓLO uno no está en la mesa, no se pide ninguno' do
      en_deposito = stock!(visible)

      pedir(items: [{ stock_id: nl.id, cantidad: 10 }, { stock_id: en_deposito.id, cantidad: 5 }])

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Reserva.count).to eq(0)
    end

    it 'una genética que la organización no publica no se pide, aunque esté en la mesa' do
      secreta = stock!(oculta).tap { |s| a_la_mesa!(s, 100) }
      pedir(items: [{ stock_id: secreta.id, cantidad: 10 }])
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'más de lo que hay libre: no se pide, y no le dice cuánto hay' do
      pedir(items: [{ stock_id: nl.id, cantidad: 150 }])

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['error']).to include('Hoy no hay tanto de «Northern Lights»')
      expect(json['error']).not_to include('100')
    end

    it 'lleva el precio con SU descuento, el mismo que le muestra el catálogo' do
      paciente.update!(descuento_porcentaje: 10)
      nl
      sign_in_as(cuenta)
      expect(catalogo_de_hoy['precio']).to eq(900.0)

      pedir(items: [{ stock_id: nl.id, cantidad: 2 }])
      expect(json['data']['total_estimado']).to eq(1800.0)
    end

    describe 'una reserva por día' do
      it 'dos para el mismo día, no' do
        pedir(items: [{ stock_id: nl.id, cantidad: 10 }])
        pedir(items: [{ stock_id: nl.id, cantidad: 5 }])

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json['error']).to include('Ya tenés una reserva para hoy')
      end

      it 'una para hoy y otra para mañana, sí, aunque la de hoy todavía espere' do
        pedir(items: [{ stock_id: nl.id, cantidad: 10 }], fecha: hoy)
        pedir(items: [{ stock_id: nl.id, cantidad: 5 }], fecha: hoy + 1)

        expect(response).to have_http_status(:created), response.body
        expect(Reserva.where(paciente_id: paciente.id).count).to eq(2)
      end

      it 'la ya confirmada también ocupa el día' do
        pedir(items: [{ stock_id: nl.id, cantidad: 10 }])
        Reserva.last.confirmar!(por: admin)

        pedir(items: [{ stock_id: nl.id, cantidad: 5 }])
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'la que le cargó la organización para ese día también cuenta' do
        Reserva.create!(club: club, paciente: paciente, user: admin, stock: nl, cantidad: 5, fecha_entrega_estimada: hoy + 1)

        pedir(items: [{ stock_id: nl.id, cantidad: 5 }], fecha: hoy + 1)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'si la cancela o se la rechazan, el día vuelve a quedar libre' do
        pedir(items: [{ stock_id: nl.id, cantidad: 10 }])
        Reserva.last.rechazar!(por: admin, motivo: 'Hoy no')

        pedir(items: [{ stock_id: nl.id, cantidad: 5 }])
        expect(response).to have_http_status(:created), response.body
      end
    end

    it 'un paciente pendiente de aprobación no pide' do
      pendiente = create(:paciente, club: club, created_by: admin)
      usuario = cuenta_de(pendiente)
      pendiente.update_column(:aprobado_at, nil) # el alta sin admitir (del mostrador)
      pedir(items: [{ stock_id: nl.id, cantidad: 10 }], como: usuario)
      expect(response.status).to be_in([403, 422])
      expect(Reserva.count).to eq(0)
    end
  end

  describe 'sus pedidos' do
    it 've los suyos con el estado y el motivo del rechazo; no los de otro paciente' do
      pedir(items: [{ stock_id: nl.id, cantidad: 10 }])
      reserva = Reserva.last
      reserva.rechazar!(por: admin, motivo: 'Hoy cerramos temprano')
      otro = create(:paciente, club: club, created_by: admin, aprobado_at: Time.current)
      pedir(items: [{ stock_id: nl.id, cantidad: 3 }], como: cuenta_de(otro))

      sign_in_as(cuenta)
      get '/api/portal/reservas'

      expect(json['data'].size).to eq(1)
      expect(json['data'].first).to include('estado' => 'rechazada', 'motivo_rechazo' => 'Hoy cerramos temprano')
      expect(json['data'].first.keys).not_to include('notas', 'user_id', 'sena_ars')
    end

    it 'trae los días que puede elegir (hoy y mañana) y cuál le queda libre' do
      sign_in_as(cuenta)
      get '/api/portal/reservas'
      expect(json['fechas_retiro']).to eq([{ 'fecha' => hoy.iso8601, 'etiqueta' => 'Hoy', 'libre' => true },
                                           { 'fecha' => (hoy + 1).iso8601, 'etiqueta' => 'Mañana', 'libre' => true }])

      pedir(items: [{ stock_id: nl.id, cantidad: 10 }], fecha: hoy)
      get '/api/portal/reservas'
      expect(json['fechas_retiro'].map { |f| f['libre'] }).to eq([false, true])
    end

    it 'cancela el suyo mientras nadie lo confirmó' do
      pedir(items: [{ stock_id: nl.id, cantidad: 10 }])
      patch "/api/portal/reservas/#{json['data']['id']}/cancelar"

      expect(response).to have_http_status(:ok)
      expect(json['data']['estado']).to eq('cancelada')
    end

    it 'uno ya confirmado no lo cancela desde el portal' do
      pedir(items: [{ stock_id: nl.id, cantidad: 10 }])
      Reserva.last.confirmar!(por: admin)

      sign_in_as(cuenta)
      patch "/api/portal/reservas/#{Reserva.last.id}/cancelar"
      expect(response).to have_http_status(:unprocessable_entity)
      expect(Reserva.last.estado).to eq('pendiente')
    end

    it 'el de otro paciente no lo encuentra' do
      otro = create(:paciente, club: club, created_by: admin, aprobado_at: Time.current)
      pedir(items: [{ stock_id: nl.id, cantidad: 10 }], como: cuenta_de(otro))
      id = json['data']['id']

      sign_in_as(cuenta)
      patch "/api/portal/reservas/#{id}/cancelar"
      expect(response).to have_http_status(:not_found)
      expect(Reserva.find(id).estado).to eq('solicitada')
    end
  end

  describe 'administración confirma o rechaza' do
    let!(:pedido) do
      pedir(items: [{ stock_id: nl.id, cantidad: 10 }])
      Reserva.find(json['data']['id'])
    end

    [:admin, :supervisor].each do |rol|
      it "#{rol}: al confirmar pasa a reserva y recién ahí aparta de la mesa" do
        libre_antes = nl.libre_en_mostrador(sede.id)
        sign_in_as(send(rol))

        patch "/api/reservas/#{pedido.id}/confirmar"

        expect(response).to have_http_status(:ok), response.body
        expect(pedido.reload).to have_attributes(estado: 'pendiente', confirmada_por_id: send(rol).id)
        expect(nl.reload.libre_en_mostrador(sede.id)).to eq(libre_antes - 10)
      end
    end

    it 'el dispensador no confirma, y ni siquiera ve el pedido en la lista' do
      sign_in_as(dispensador)

      patch "/api/reservas/#{pedido.id}/confirmar"
      expect(response).to have_http_status(:forbidden)

      get '/api/reservas'
      expect(json['reservas'].map { |r| r['id'] }).not_to include(pedido.id)
    end

    it 'el admin sí lo ve en la lista de pedidos' do
      sign_in_as(admin)
      get '/api/reservas', params: { estado: 'solicitada' }
      expect(json['reservas'].map { |r| r['id'] }).to eq([pedido.id])
      expect(json['reservas'].first).to include('origen' => 'portal')
    end

    it 'rechazar pide el motivo' do
      sign_in_as(admin)

      patch "/api/reservas/#{pedido.id}/rechazar", params: { motivo: '' }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)

      patch "/api/reservas/#{pedido.id}/rechazar", params: { motivo: 'No tenemos para mañana' }, as: :json
      expect(response).to have_http_status(:ok)
      expect(pedido.reload).to have_attributes(estado: 'rechazada', motivo_rechazo: 'No tenemos para mañana')
    end

    it 'si entre el pedido y la confirmación se fue lo de la mesa, no se confirma' do
      Reserva.create!(club: club, paciente: create(:paciente, club: club, created_by: admin, aprobado_at: Time.current),
                      user: admin, stock: nl, cantidad: 95, fecha_entrega_estimada: hoy + 1)
      sign_in_as(admin)

      patch "/api/reservas/#{pedido.id}/confirmar"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(pedido.reload.estado).to eq('solicitada')
    end

    it 'confirmar le avisa al paciente por su canal' do
      sign_in_as(admin)
      expect { patch "/api/reservas/#{pedido.id}/confirmar" }
        .to have_broadcasted_to(PacienteChannel.stream(paciente.id)).with(hash_including(recurso: 'reservas', accion: 'pendiente'))
    end

    it 'el admin de otra organización no lo encuentra' do
      otro_club = create(:club, features: { 'produccion_dispensa' => true })
      sign_in_as(create(:user, :admin, club: otro_club))

      patch "/api/reservas/#{pedido.id}/confirmar"

      expect(response).to have_http_status(:not_found)
      expect(pedido.reload.estado).to eq('solicitada')
    end

    it 'un pedido que nadie confirmó y cuyo día pasó, vence solo' do
      pedido.update_columns(fecha_entrega_estimada: hoy - 1)
      VencimientoReservasJob.new.perform
      expect(pedido.reload.estado).to eq('vencida')
    end
  end

  # Con el portal cerrado (o sin contratar) el paciente ni entra (el login lo frena). Lo que se prueba
  # acá es el que YA estaba adentro cuando la organización lo cerró: la barrera de verdad es el
  # backend del portal.
  describe 'sin el portal habilitado no existe' do
    def ya_adentro! = (nl; sign_in_as(cuenta))
    def intentar
      post '/api/portal/reservas', params: { sede_id: sede.id, fecha: hoy.iso8601, items: [{ stock_id: nl.id, cantidad: 10 }] }, as: :json
      expect(response).to have_http_status(:forbidden)
      %w[/api/portal/catalogo /api/portal/reservas].each do |ruta|
        get ruta
        expect(response).to have_http_status(:forbidden)
      end
      expect(Reserva.count).to eq(0)
    end

    it 'con el portal cerrado, el que ya estaba adentro no pide ni ve el catálogo' do
      ya_adentro!
      club.update!(vista_paciente_activa: false)
      intentar
    end

    it 'sin el módulo contratado, tampoco' do
      ya_adentro!
      club.update!(features: club.features.merge('vista_paciente' => false))
      intentar
    end

    it 'con el portal cerrado ni siquiera entra' do
      nl
      cuenta
      club.update!(vista_paciente_activa: false)
      post '/api/users/sign_in', params: { user: { email: cuenta.email, password: AuthHelpers::DEFAULT_PASSWORD } }, as: :json
      expect(response).not_to have_http_status(:ok)
    end
  end

  it 'el catálogo dice «no hay hoy» cuando todo lo de la mesa ya está reservado' do
    Reserva.create!(club: club, paciente: paciente, user: admin, stock: nl, cantidad: 100, fecha_entrega_estimada: hoy + 1)
    sign_in_as(cuenta)
    expect(catalogo_de_hoy['disponibilidad']).to eq('no_hay')
  end
end
