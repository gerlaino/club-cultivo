require 'rails_helper'

# AC: Delivery se contrata aparte (11-ago), así que sin el add-on no se reparte — y eso tiene
# que valer en la API, no sólo en el menú.
#
# Cuando pasó a ser add-on se gateó el ROL, que era la puerta visible: un repartidor sin el
# módulo no puede entrar. Pero el admin no depende del rol, así que seguía armando rutas y
# marcando envíos de un módulo que la organización no tiene contratado.
#
# La excepción, que es lo importante de este spec: **cerrar** un reparto (entregar / reportar
# fallo) sigue disponible con el módulo apagado. Es la misma decisión que ya tomó
# `AplicarBajasModulosJob`, que suelta lo pendiente y no toca lo que está en la calle: si una
# baja vence con paquetes en viaje, el repartidor tiene producto de la organización encima y
# tiene que poder registrar cómo terminó. Bloquearlo los dejaría abiertos para siempre.
RSpec.describe 'Delivery: el módulo se aplica en la API', type: :request do
  include AuthHelpers

  let(:club)        { create(:club) }
  let(:admin)       { create(:user, :admin, club: club) }
  let(:dispensador) { create(:user, :dispensador, club: club) }
  let(:repartidor)  { create(:user, club: club, role: 'delivery') }
  let(:sede)        { create(:sede, club: club, created_by: admin) }
  let(:sala)        { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)        { create(:lote, club: club, sala: sala) }
  let(:paciente) do
    create(:paciente, club: club, created_by: admin, telefono: '111',
           domicilio_calle: 'Calle', domicilio_ciudad: 'CABA')
  end
  let!(:stock) do
    Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca',
                  unidad: 'g', cantidad: 100, precio_sugerido_ars: 100)
  end

  # Apagar de verdad: `update_columns` saltea la baja programada, que es otra historia (ver
  # baja_modulo_delivery_spec). Acá se prueba la organización que directamente no lo tiene.
  def apagar_delivery!
    club.update_columns(features: club.features.merge('delivery' => false))
  end

  def crear_despacho
    post "/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { stock_id: stock.id, cantidad: 5, medio_pago: 'efectivo',
                                   aporte_socio_ars: 500, con_envio: true,
                                   delivery_id: repartidor.id, usar_domicilio_paciente: true } },
         headers: auth_headers
    expect(response).to have_http_status(:created), "crear despacho falló: #{response.body}"
    Dispensacion.last
  end

  describe 'sin el módulo contratado' do
    before { apagar_delivery!; sign_in_as(admin) }

    it 'no deja armar una ruta de reparto, aunque sea el admin' do
      get '/api/rutas_entrega', params: { delivery_id: repartidor.id, fecha: Date.current.to_s }

      expect(response).to have_http_status(:forbidden)
      body = JSON.parse(response.body)
      expect(body['requiere_modulo']).to be(true)
      expect(body['modulo']).to eq('delivery')
    end

    it 'no deja ver la lista de paquetes del día' do
      get '/api/dispensaciones/mis_paquetes'

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['modulo']).to eq('delivery')
    end

    it 'no deja a quién asignarle un envío' do
      get '/api/dispensaciones/entregadores'

      expect(response).to have_http_status(:forbidden)
    end

    it 'rechaza CREAR una dispensación con envío: el checkbox dejaba de significar algo' do
      d = Dispensacion.new(paciente: paciente, user: admin, stock: stock, cantidad: 1,
                           medio_pago: 'efectivo', fecha_dispensacion: Date.current,
                           con_envio: true, delivery_id: repartidor.id,
                           direccion_envio: 'Av. Siempreviva 742', contacto_nombre: 'Quien recibe')

      expect(d).not_to be_valid
      expect(d.errors.full_messages.join).to match(/Delivery no está contratado/i)
    end

    it 'la dispensación de mostrador sigue funcionando: lo que se corta es el envío' do
      sign_in_as(dispensador)

      post "/pacientes/#{paciente.id}/dispensaciones",
           params: { dispensacion: { stock_id: stock.id, cantidad: 5, medio_pago: 'efectivo',
                                     aporte_socio_ars: 500 } },
           headers: auth_headers

      expect(response).to have_http_status(:created), response.body
    end
  end

  # Quién cierra lo que quedó en la calle: el ADMIN, no el repartidor. Con el módulo apagado el
  # rol `delivery` no puede ni entrar (lo frena `check_rol_habilitado!` en el login), así que si
  # los cierres también estuvieran gateados no quedaría NADIE que pudiera registrar cómo terminó
  # un paquete en viaje: quedarían abiertos para siempre. Por eso `entregar` y `reportar_fallo`
  # están afuera del `require_feature!`.
  describe 'lo que ya está en la calle cuando se apaga el módulo' do
    # El paquete se creó MIENTRAS el módulo estaba contratado. Es el único orden posible: la
    # validación de `Dispensacion` impide crearlo después.
    let!(:despacho) do
      sign_in_as(dispensador)
      d = crear_despacho
      d.update_columns(estado_envio: 'en_viaje')
      d
    end

    before { apagar_delivery!; relogin(admin) }

    it 'el repartidor ya no puede entrar: su rol vive del módulo' do
      delete '/api/users/sign_out'
      post '/api/users/sign_in',
           params: { user: { email: repartidor.email, password: 'password123' } }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['modulo_rol_apagado']).to be(true)
    end

    it 'el admin puede entregar: alguien tiene que poder cerrarlo' do
      patch "/dispensaciones/#{despacho.id}/entregar",
            params: { notas_entrega: 'Entregado en mano' }, headers: auth_headers

      expect(response).to have_http_status(:ok), response.body
      expect(despacho.reload.estado_envio).to eq('entregado')
    end

    it 'se puede reportar el fallo, que es el otro final posible' do
      patch "/dispensaciones/#{despacho.id}/reportar_fallo",
            params: { motivo_fallo: 'No había nadie' }, headers: auth_headers

      expect(response).to have_http_status(:ok), response.body
      expect(despacho.reload.estado_envio).to eq('fallido')
    end

    it 'pero no se puede arrancar un viaje nuevo' do
      patch '/api/dispensaciones/iniciar_viaje', params: { ids: [despacho.id] }

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['modulo']).to eq('delivery')
    end
  end

  def relogin(user)
    delete '/api/users/sign_out'
    sign_in_as(user)
  end
end
