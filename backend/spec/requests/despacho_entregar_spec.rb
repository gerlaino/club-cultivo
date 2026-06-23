require 'rails_helper'

RSpec.describe 'PATCH /dispensaciones/:id/entregar (delivery)', type: :request do
  include AuthHelpers

  let(:club)        { create(:club) }
  let(:admin)       { create(:user, :admin, club: club) }
  let(:dispensador) { create(:user, :dispensador, club: club) }
  let(:delivery)    { create(:user, club: club, role: 'delivery') }
  let(:sede)        { create(:sede, club: club, created_by: admin) }
  let(:sala)        { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)        { create(:lote, club: club, sala: sala) }
  let(:paciente) do
    create(:paciente, club: club, created_by: admin, telefono: '1',
           domicilio_calle: 'Calle', domicilio_ciudad: 'CABA')
  end
  let!(:stock) { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100, precio_sugerido_ars: 100) }

  def crear_despacho
    post "/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { stock_id: stock.id, cantidad: 5, medio_pago: 'efectivo', aporte_socio_ars: 500,
                                   con_envio: true, delivery_id: delivery.id, usar_domicilio_paciente: true } },
         headers: auth_headers
    expect(response).to have_http_status(:created)
    Dispensacion.last
  end

  it 'el delivery marca un despacho como entregado' do
    sign_in_as(dispensador)
    d = crear_despacho
    delete '/api/users/sign_out'
    sign_in_as(delivery)
    patch "/dispensaciones/#{d.id}/entregar", params: { notas_entrega: 'OK' }, headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(d.reload.estado_envio).to eq('entregado')
  end

  it 'no rompe (422) aunque el despacho tenga un campo de envío vacío (data vieja)' do
    sign_in_as(dispensador)
    d = crear_despacho
    # Simula data vieja: un despacho con contacto_nombre vacío.
    d.update_column(:contacto_nombre, nil)

    delete '/api/users/sign_out'
    sign_in_as(delivery)
    patch "/dispensaciones/#{d.id}/entregar", params: {}, headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(d.reload.estado_envio).to eq('entregado')
  end
end
