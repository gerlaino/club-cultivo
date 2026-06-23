require 'rails_helper'

RSpec.describe 'Rutas de entrega', type: :request do
  include AuthHelpers

  let(:club)        { create(:club) }
  let(:admin)       { create(:user, :admin, club: club) }
  let(:dispensador) { create(:user, :dispensador, club: club) }
  let(:delivery)    { create(:user, club: club, role: 'delivery') }
  let(:sede)        { create(:sede, club: club, created_by: admin) }
  let(:sala)        { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)        { create(:lote, club: club, sala: sala) }
  let(:paciente) do
    create(:paciente, club: club, created_by: admin, telefono: '111',
           domicilio_calle: 'Calle', domicilio_ciudad: 'CABA')
  end
  let!(:stock) { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100, precio_sugerido_ars: 100) }

  def relogin(user)
    delete '/api/users/sign_out'
    sign_in_as(user)
  end

  def crear_despacho
    post "/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { stock_id: stock.id, cantidad: 5, medio_pago: 'efectivo',
                                   aporte_socio_ars: 500, con_envio: true, delivery_id: delivery.id,
                                   usar_domicilio_paciente: true } },
         headers: auth_headers
    expect(response).to have_http_status(:created), "crear despacho falló: #{response.body}"
    Dispensacion.last
  end

  it 'ordena los despachos, los bloquea y el delivery los recibe en ese orden' do
    sign_in_as(dispensador)
    d1 = crear_despacho
    d2 = crear_despacho

    # Admin ordena: d2 primero, d1 segundo
    relogin(admin)
    post '/rutas_entrega/ordenar',
         params: { delivery_id: delivery.id, fecha: Date.current.to_s, orden: [d2.id, d1.id] },
         headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(d2.reload.orden_entrega).to eq(1)
    expect(d1.reload.orden_entrega).to eq(2)
    ruta_id = JSON.parse(response.body)['id']
    expect(d1.ruta_entrega_id).to eq(ruta_id)

    # Bloquea la ruta
    patch "/rutas_entrega/#{ruta_id}/bloqueo", params: { bloqueada: true }, headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['bloqueada']).to be(true)

    # El delivery ve sus paquetes en el orden de la ruta y con la marca de bloqueo
    relogin(delivery)
    get '/dispensaciones/mis_paquetes', headers: auth_headers
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)['dispensaciones']
    expect(body.map { |x| x['id'] }).to eq([d2.id, d1.id])
    expect(body.first['ruta_bloqueada']).to be(true)
    expect(body.first['orden_entrega']).to eq(1)
  end

  it 'no asigna a la ruta despachos de otro club (aislamiento)' do
    otro_club  = create(:club)
    otro_disp  = create(:user, :dispensador, club: otro_club)
    otro_admin = create(:user, :admin, club: otro_club)
    otro_sede  = create(:sede, club: otro_club, created_by: otro_admin)
    otro_sala  = create(:sala, club: otro_club, sede: otro_sede, created_by: otro_admin)
    otro_lote  = create(:lote, club: otro_club, sala: otro_sala)
    otro_stock = Stock.create!(sede: otro_sede, lote: otro_lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 50, precio_sugerido_ars: 100)
    otro_pac   = create(:paciente, club: otro_club, created_by: otro_admin, domicilio_calle: 'X', domicilio_ciudad: 'Y')
    otro_deliv = create(:user, club: otro_club, role: 'delivery')

    sign_in_as(otro_disp)
    post "/pacientes/#{otro_pac.id}/dispensaciones",
         params: { dispensacion: { stock_id: otro_stock.id, cantidad: 1, medio_pago: 'efectivo', aporte_socio_ars: 100,
                                   con_envio: true, delivery_id: otro_deliv.id, usar_domicilio_paciente: true } },
         headers: auth_headers
    ajeno = Dispensacion.last

    relogin(admin)
    post '/rutas_entrega/ordenar',
         params: { delivery_id: delivery.id, fecha: Date.current.to_s, orden: [ajeno.id] },
         headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(ajeno.reload.ruta_entrega_id).to be_nil
  end

  it 'permite armar la ruta para una fecha futura (no solo hoy)' do
    sign_in_as(dispensador)
    d1 = crear_despacho
    futuro = (Date.current + 5).to_s

    relogin(admin)
    post '/rutas_entrega/ordenar',
         params: { delivery_id: delivery.id, fecha: futuro, orden: [d1.id] },
         headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['fecha']).to eq(futuro)

    # La ruta de hoy queda vacía; la futura tiene el despacho
    get '/rutas_entrega', params: { delivery_id: delivery.id, fecha: Date.current.to_s }, headers: auth_headers
    expect(JSON.parse(response.body)['ruta']).to be_nil
    get '/rutas_entrega', params: { delivery_id: delivery.id, fecha: futuro }, headers: auth_headers
    expect(JSON.parse(response.body)['despachos']).to eq([d1.id])
  end

  it 'el delivery puede ordenar su propia ruta (no bloqueada)' do
    sign_in_as(dispensador)
    d1 = crear_despacho
    relogin(delivery)
    post '/rutas_entrega/ordenar',
         params: { delivery_id: delivery.id, fecha: Date.current.to_s, orden: [d1.id] },
         headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(d1.reload.orden_entrega).to eq(1)
  end

  it 'el delivery NO puede ordenar la ruta de otro repartidor' do
    otro = create(:user, club: club, role: 'delivery')
    sign_in_as(delivery)
    post '/rutas_entrega/ordenar',
         params: { delivery_id: otro.id, fecha: Date.current.to_s, orden: [] },
         headers: auth_headers
    expect(response).to have_http_status(:forbidden)
  end

  it 'el delivery NO puede reordenar una ruta fijada por el club' do
    sign_in_as(dispensador)
    d1 = crear_despacho
    relogin(admin)
    post '/rutas_entrega/ordenar', params: { delivery_id: delivery.id, fecha: Date.current.to_s, orden: [d1.id] }, headers: auth_headers
    ruta_id = JSON.parse(response.body)['id']
    patch "/rutas_entrega/#{ruta_id}/bloqueo", params: { bloqueada: true }, headers: auth_headers

    relogin(delivery)
    post '/rutas_entrega/ordenar', params: { delivery_id: delivery.id, fecha: Date.current.to_s, orden: [d1.id] }, headers: auth_headers
    expect(response).to have_http_status(:forbidden)
  end
end
