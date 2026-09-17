require 'rails_helper'

RSpec.describe 'Dispensación con envío — dirección', type: :request do
  let(:club)        { create(:club) }
  let(:admin)       { create(:user, :admin, club: club) }
  let(:dispensador) { create(:user, :dispensador, club: club) }
  let(:delivery)    { create(:user, club: club, role: 'delivery') }
  let(:sede)        { create(:sede, club: club, created_by: admin) }
  let(:sala)        { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)        { create(:lote, club: club, sala: sala) }
  let(:paciente) do
    create(:paciente, club: club, created_by: admin, telefono: '1133334444',
           domicilio_calle: 'Av. Siempreviva', domicilio_altura: '742',
           domicilio_barrio: 'Palermo', domicilio_ciudad: 'CABA')
  end
  let!(:stock) { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100, precio_sugerido_ars: 100) }

  before { sign_in_as(dispensador) }

  def crear(envio_attrs)
    post "/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { stock_id: stock.id, cantidad: 5, medio_pago: 'efectivo',
                                   aporte_socio_ars: 500, con_envio: true, delivery_id: delivery.id }.merge(envio_attrs) },
         headers: auth_headers
  end

  it 'usa el domicilio del paciente y compone la dirección' do
    crear(usar_domicilio_paciente: true)
    expect(response).to have_http_status(:created)
    d = Dispensacion.last
    expect(d.envio_calle).to eq('Av. Siempreviva')
    expect(d.direccion_envio).to eq('Av. Siempreviva 742, Palermo, CABA')
    # Para Maps: sólo calle, altura y localidad. El barrio, el piso y el depto confunden el
    # geocoding («Directorio 1602, Depto TRABAJO, CABA» no lo encuentra).
    expect(d.direccion_envio_maps).to eq('Av. Siempreviva 742, CABA')
  end

  it 'el paquete que ve el repartidor trae la dirección para Maps aparte de la completa' do
    crear(usar_domicilio_paciente: false, envio_calle: 'Directorio', envio_altura: '1602',
          envio_depto: 'TRABAJO', envio_ciudad: 'CABA')

    j = JSON.parse(response.body)
    expect(j['direccion_envio']).to eq('Directorio 1602, Depto TRABAJO, CABA')
    expect(j['direccion_maps']).to  eq('Directorio 1602, CABA')
  end

  it 'acepta otra dirección estructurada y la compone (con piso/depto)' do
    crear(usar_domicilio_paciente: false, envio_calle: 'Corrientes', envio_altura: '1000',
          envio_piso: '3', envio_depto: 'B', envio_ciudad: 'CABA')
    expect(response).to have_http_status(:created)
    d = Dispensacion.last
    expect(d.direccion_envio).to eq('Corrientes 1000, Piso 3 Depto B, CABA')
    # Maps ignora piso/depto
    expect(d.direccion_envio_maps).to eq('Corrientes 1000, CABA')
  end

  # AC (socio de Germán, 16-sep-2026, primer reparto de Mitocondria ONG): con las DOS direcciones
  # cargadas, «domicilio del paciente» mandaba a la de ENVÍO sin decirlo y la otra no se podía
  # elegir. Ahora la pantalla elige POR NOMBRE y ve el texto antes de confirmar.
  describe 'eligiendo la dirección por su nombre' do
    before { paciente.update!(envio_calle: 'Lavalle', envio_altura: '400', envio_ciudad: 'CABA') }

    it 'las dos direcciones se consultan con nombre y texto' do
      get "/pacientes/#{paciente.id}/direcciones", headers: auth_headers

      j = JSON.parse(response.body)
      expect(j['domicilio']['label']).to eq('Domicilio REPROCANN')
      expect(j['domicilio']['texto']).to eq('Av. Siempreviva 742, Palermo, CABA')
      expect(j['envio']['label']).to     eq('Dirección de envío')
      expect(j['envio']['texto']).to     eq('Lavalle 400, CABA')
    end

    it 'sin dirección de envío cargada, esa viene en nil' do
      paciente.update!(envio_calle: nil)
      get "/pacientes/#{paciente.id}/direcciones", headers: auth_headers

      expect(JSON.parse(response.body)['envio']).to be_nil
    end

    it '«domicilio» manda al domicilio aunque tenga dirección de envío' do
      crear(direccion_origen: 'domicilio')

      expect(response).to have_http_status(:created)
      expect(Dispensacion.last.direccion_envio).to eq('Av. Siempreviva 742, Palermo, CABA')
    end

    it '«envio» manda a la de envío' do
      crear(direccion_origen: 'envio')

      expect(Dispensacion.last.direccion_envio).to eq('Lavalle 400, CABA')
    end

    it 'elegir una que no tiene cargada rebota con el motivo, no con un paquete sin dirección' do
      paciente.update!(envio_calle: nil)
      crear(direccion_origen: 'envio')

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['errors'].first).to include('dirección de envío')
    end

    it '«otra» exige calle, altura y ciudad' do
      crear(direccion_origen: 'otra', envio_calle: 'Corrientes')

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it '«otra» con «guardar como envío» queda en la ficha para la próxima' do
      crear(direccion_origen: 'otra', envio_calle: 'Corrientes', envio_altura: '1000', envio_ciudad: 'CABA', guardar_como_envio: true)

      expect(response).to have_http_status(:created)
      expect(paciente.reload.envio_calle).to eq('Corrientes')
      expect(paciente.direccion('envio')[:texto]).to eq('Corrientes 1000, CABA')
    end

    # Con el carrito (items) la dispensa se arma DESPUÉS de resolver la dirección: guardar en la
    # ficha con `update!` validaba al paciente con esa dispensa a medias y rebotaba con
    # «Dispensaciones no es válido» (producción, 17-sep).
    it '«otra» con guardar también anda con el carrito multi-producto' do
      post "/pacientes/#{paciente.id}/dispensaciones",
           params: { dispensacion: { items: [{ stock_id: stock.id, cantidad: 5 }], medio_pago: 'efectivo', aporte_socio_ars: 500,
                                     con_envio: true, delivery_id: delivery.id, direccion_origen: 'otra',
                                     envio_calle: 'Balbastro', envio_altura: '1265', envio_ciudad: 'CABA', envio_etiqueta: 'Hobby',
                                     guardar_como_envio: true, contacto_nombre: 'Example' } },
           headers: auth_headers

      expect(response).to have_http_status(:created), response.body
      expect(paciente.reload.envio_calle).to eq('Balbastro')
    end

    it '«otra» sin guardar no toca la ficha' do
      crear(direccion_origen: 'otra', envio_calle: 'Corrientes', envio_altura: '1000', envio_ciudad: 'CABA')

      expect(paciente.reload.envio_calle).to eq('Lavalle')
    end

    # El nombre de la dirección («Trabajo»): el socio de Germán lo escribió en Depto porque no
    # había otro lugar, y Maps dejó de encontrarla. Viaja con el paquete como snapshot.
    it 'la de envío lleva su etiqueta, y el paquete la conserva' do
      paciente.update!(envio_etiqueta: 'Trabajo')

      get "/pacientes/#{paciente.id}/direcciones", headers: auth_headers
      expect(JSON.parse(response.body)['envio']['etiqueta']).to eq('Trabajo')

      crear(direccion_origen: 'envio')
      d = Dispensacion.last
      expect(d.direccion_etiqueta).to eq('Trabajo')
      expect(DispensacionSerializer.serialize_delivery(d)[:direccion_etiqueta]).to eq('Trabajo')
    end

    it '«otra» con etiqueta y guardar: la ficha queda con nombre y el paquete también' do
      crear(direccion_origen: 'otra', envio_calle: 'Directorio', envio_altura: '1602', envio_ciudad: 'CABA',
            envio_etiqueta: 'Trabajo', guardar_como_envio: true)

      expect(paciente.reload.envio_etiqueta).to eq('Trabajo')
      expect(Dispensacion.last.direccion_etiqueta).to eq('Trabajo')
      expect(Dispensacion.last.direccion_envio).to eq('Directorio 1602, CABA')
    end

    # El bundle viejo de la PWA sigue mandando `usar_domicilio_paciente`: no puede romperse.
    it 'el cliente viejo sigue resolviendo como antes' do
      crear(usar_domicilio_paciente: true)

      expect(response).to have_http_status(:created)
      expect(Dispensacion.last.direccion_envio).to eq('Lavalle 400, CABA')
    end
  end
end
