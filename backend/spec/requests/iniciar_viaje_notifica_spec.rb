require 'rails_helper'

RSpec.describe 'PATCH /dispensaciones/iniciar_viaje — notifica al socio', type: :request do
  include AuthHelpers

  let(:club) do
    create(:club, name: 'Mi Club',
           smtp_host: 'smtp.gmail.com', smtp_port: 587, smtp_user: 'miclub@gmail.com',
           smtp_pass: 'app-pass', smtp_from: 'miclub@gmail.com', smtp_from_name: 'Mi Club')
  end
  let(:admin)    { create(:user, :admin, club: club) }
  let(:delivery) { create(:user, club: club, role: 'delivery') }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)     { create(:lote, club: club, sala: sala) }
  let(:paciente) { create(:paciente, club: club, created_by: admin, email: 'socio@gmail.com') }
  let!(:stock)   { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100, precio_sugerido_ars: 10) }

  let!(:disp) do
    Dispensacion.create!(paciente: paciente, user: admin, stock: stock, sede: sede,
                         cantidad: 1, medio_pago: 'efectivo', fecha_dispensacion: Date.today, aporte_socio_ars: 10,
                         con_envio: true, delivery_id: delivery.id, estado_envio: 'pendiente',
                         direccion_envio: 'Calle Falsa 123', contacto_nombre: 'German', contacto_telefono: '1140000000')
  end

  it 'al iniciar el viaje pasa a en_viaje y manda el mail al socio' do
    sign_in_as(delivery)
    expect {
      patch '/dispensaciones/iniciar_viaje', params: { ids: [disp.id] }, headers: auth_headers, as: :json
    }.to change { ActionMailer::Base.deliveries.size }.by(1)
    expect(response).to have_http_status(:ok)
    expect(disp.reload.estado_envio).to eq('en_viaje')

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq(['socio@gmail.com'])
    expect(mail.from).to eq(['miclub@gmail.com'])
  end

  it 'no manda mail si el club no conectó su correo (no rompe el viaje)' do
    club.update!(smtp_host: nil, smtp_user: nil, smtp_pass: nil, smtp_from: nil)
    sign_in_as(delivery)
    expect {
      patch '/dispensaciones/iniciar_viaje', params: { ids: [disp.id] }, headers: auth_headers, as: :json
    }.not_to change { ActionMailer::Base.deliveries.size }
    expect(response).to have_http_status(:ok)
    expect(disp.reload.estado_envio).to eq('en_viaje') # el viaje arranca igual
  end
end
