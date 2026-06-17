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
    expect(d.direccion_envio_maps).to eq('Av. Siempreviva 742, Palermo, CABA')
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
end
