require 'rails_helper'

# AC (socio de Germán, 16-sep-2026): el dispensador ve los envíos que despachó HOY y cómo van,
# actualizados a medida que el repartidor los marca. Administración puede ver los de todos.
RSpec.describe 'Envíos del día', type: :request do
  let(:club)        { create(:club) }
  let(:admin)       { create(:user, :admin, club: club) }
  let(:dispensador) { create(:user, :dispensador, club: club) }
  # Un supervisor: es administración, dispensa del depósito sin pasar por el mostrador.
  let(:otro_disp)   { create(:user, club: club, role: 'supervisor') }
  let(:delivery)    { create(:user, club: club, role: 'delivery', first_name: 'Rapi', last_name: 'Do') }
  let(:sede)        { create(:sede, club: club, created_by: admin, tipo: 'mixta') }
  let(:sala)        { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)        { create(:lote, club: club, sala: sala) }
  let(:paciente)    { create(:paciente, club: club, created_by: admin, domicilio_calle: 'Av. Siempreviva', domicilio_altura: '742', domicilio_ciudad: 'CABA') }
  let!(:stock)      { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100, precio_sugerido_ars: 100) }

  def json = JSON.parse(response.body)

  # Quien atiende dispensa de la mesa y con la caja abierta, como en la vida real.
  before { abrir_mostrador!(sede, usuario: admin, recibe: dispensador) }

  def dispensar_con_envio(quien, fecha: Time.zone.today, con_envio: true)
    sign_in_as(quien)
    post "/api/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { stock_id: stock.id, cantidad: 1, medio_pago: 'efectivo', aporte_socio_ars: 100,
                                   fecha_dispensacion: fecha.to_s, con_envio: con_envio, delivery_id: delivery.id,
                                   direccion_origen: 'domicilio', contacto_nombre: 'X' } }, as: :json
    expect(response).to have_http_status(:created), response.body
    Dispensacion.find(json['id'])
  end

  it 'el dispensador ve SUS envíos de hoy, con estado, repartidor y dirección' do
    mia   = dispensar_con_envio(dispensador)
    dispensar_con_envio(otro_disp)
    dispensar_con_envio(dispensador, fecha: Time.zone.today - 1)
    dispensar_con_envio(dispensador, con_envio: false)

    sign_in_as(dispensador)
    get '/api/dispensaciones/envios_del_dia'

    expect(response).to have_http_status(:ok)
    expect(json.map { |e| e['id'] }).to eq([mia.id])
    fila = json.first
    expect(fila['estado_envio']).to     eq('pendiente')
    expect(fila['delivery']['nombre']).to eq('Rapi Do')
    expect(fila['direccion_envio']).to  eq('Av. Siempreviva 742, CABA')
    expect(fila['paciente']['nombre']).to eq(paciente.nombre_completo)
  end

  it 'administración con `todos=1` ve los de todo el equipo; sin el flag, los propios' do
    dispensar_con_envio(dispensador)
    dispensar_con_envio(otro_disp)

    sign_in_as(admin)
    get '/api/dispensaciones/envios_del_dia', params: { todos: 1 }
    expect(json.size).to eq(2)

    get '/api/dispensaciones/envios_del_dia'
    expect(json).to be_empty
  end

  it 'el dispensador no ve los de todos aunque lo pida' do
    dispensar_con_envio(otro_disp)

    sign_in_as(dispensador)
    get '/api/dispensaciones/envios_del_dia', params: { todos: 1 }

    expect(json).to be_empty
  end

  it 'cuando el repartidor lo marca, el estado cambia y suena el timbre del club' do
    d = dispensar_con_envio(dispensador)

    expect(ActionCable.server).to receive(:broadcast)
      .with("stocks_club_#{club.id}", hash_including(tipo: 'envio_actualizado', dispensacion_id: d.id, estado_envio: 'en_viaje'))
    allow(ActionCable.server).to receive(:broadcast).and_call_original

    d.update!(estado_envio: 'en_viaje')

    sign_in_as(dispensador)
    get '/api/dispensaciones/envios_del_dia'
    expect(json.first['estado_envio']).to eq('en_viaje')
  end

  it 'otra organización no ve nada' do
    dispensar_con_envio(dispensador)
    ajeno = create(:user, :dispensador, club: create(:club))

    sign_in_as(ajeno)
    get '/api/dispensaciones/envios_del_dia'

    expect(response).to have_http_status(:ok)
    expect(json).to be_empty
  end
end
