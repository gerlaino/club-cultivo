require 'rails_helper'

RSpec.describe 'Cambio de rol — guard de despachos pendientes', type: :request do
  include AuthHelpers

  let(:club)        { create(:club) }
  let(:admin)       { create(:user, :admin, club: club) }
  let(:delivery)    { create(:user, club: club, role: 'delivery') }
  let(:dispensador) { create(:user, :dispensador, club: club) }
  let(:sede)        { create(:sede, club: club, created_by: admin) }
  let(:sala)        { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)        { create(:lote, club: club, sala: sala) }
  let(:paciente) do
    create(:paciente, club: club, created_by: admin, telefono: '1',
           domicilio_calle: 'X', domicilio_ciudad: 'Y')
  end
  let!(:stock) { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100, precio_sugerido_ars: 100) }

  def crear_despacho
    post "/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { stock_id: stock.id, cantidad: 5, medio_pago: 'efectivo', aporte_socio_ars: 500,
                                   con_envio: true, delivery_id: delivery.id, usar_domicilio_paciente: true } },
         headers: auth_headers
  end

  it 'bloquea cambiar el rol de un delivery con despachos pendientes' do
    sign_in_as(dispensador)
    crear_despacho
    expect(response).to have_http_status(:created)

    delete '/api/users/sign_out'
    sign_in_as(admin)
    patch "/usuarios/#{delivery.id}", params: { user: { role: 'cultivador' } }, headers: auth_headers

    expect(response).to have_http_status(:unprocessable_entity)
    expect(delivery.reload.role).to eq('delivery')
    expect(JSON.parse(response.body)['errors'].first).to match(/pendiente/)
  end

  it 'permite cambiar el rol de un delivery sin despachos pendientes' do
    sign_in_as(admin)
    patch "/usuarios/#{delivery.id}", params: { user: { role: 'cultivador' } }, headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(delivery.reload.role).to eq('cultivador')
  end
end
