require 'rails_helper'

RSpec.describe 'Notificaciones de una ruta de entregas', type: :request do
  include AuthHelpers

  let(:club) do
    create(:club, name: 'Mi Club',
           smtp_host: 'smtp.gmail.com', smtp_port: 587, smtp_user: 'miclub@gmail.com',
           smtp_pass: 'app-pass', smtp_from: 'miclub@gmail.com', smtp_from_name: 'Mi Club')
  end
  let!(:admin)   { create(:user, :admin, club: club, email: 'admin@miclub.com') }
  let(:delivery) { create(:user, club: club, role: 'delivery') }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)     { create(:lote, club: club, sala: sala) }
  let(:pac1)     { create(:paciente, club: club, created_by: admin, email: 'uno@gmail.com') }
  let(:pac2)     { create(:paciente, club: club, created_by: admin, email: 'dos@gmail.com') }
  let!(:stock)   { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100, precio_sugerido_ars: 10) }

  def crear_paquete(pac, orden)
    Dispensacion.create!(paciente: pac, user: admin, stock: stock, sede: sede,
                         cantidad: 1, medio_pago: 'efectivo', fecha_dispensacion: Date.today, aporte_socio_ars: 10,
                         con_envio: true, delivery_id: delivery.id, estado_envio: 'pendiente',
                         direccion_envio: 'Calle 1', contacto_nombre: 'C', orden_entrega: orden)
  end

  let!(:d1) { crear_paquete(pac1, 1) }
  let!(:d2) { crear_paquete(pac2, 2) }

  def destinatarios = ActionMailer::Base.deliveries.map { |m| m.to.first }

  it 'flujo completo: inicio, próximo, entrega, siguiente y resumen al club' do
    sign_in_as(delivery)

    # 1) Iniciar viaje: el primero (d1) recibe "próximo", el segundo (d2) "empezó el recorrido".
    expect {
      patch '/dispensaciones/iniciar_viaje', params: { ids: [d1.id, d2.id] }, headers: auth_headers, as: :json
    }.to change { ActionMailer::Base.deliveries.size }.by(2)
    expect(destinatarios).to include('uno@gmail.com', 'dos@gmail.com')

    # 2) Entregar d1: el socio recibe "entregado" y d2 (nuevo próximo) recibe "sos el próximo".
    ActionMailer::Base.deliveries.clear
    expect {
      patch "/dispensaciones/#{d1.id}/entregar", headers: auth_headers, as: :json
    }.to change { ActionMailer::Base.deliveries.size }.by(2)
    expect(destinatarios).to include('uno@gmail.com', 'dos@gmail.com')
    # Todavía queda d2 en viaje → no se mandó resumen al admin
    expect(destinatarios).not_to include('admin@miclub.com')

    # 3) Entregar d2 (último): el socio recibe "entregado" y al club le llega el RESUMEN.
    ActionMailer::Base.deliveries.clear
    patch "/dispensaciones/#{d2.id}/entregar", headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(destinatarios).to include('dos@gmail.com')        # entregado al socio
    expect(destinatarios).to include('admin@miclub.com')     # resumen al club
  end

  it 'fallo: el socio recibe el aviso de comunicarse con la administración' do
    sign_in_as(delivery)
    patch '/dispensaciones/iniciar_viaje', params: { ids: [d1.id, d2.id] }, headers: auth_headers, as: :json
    ActionMailer::Base.deliveries.clear

    patch "/dispensaciones/#{d1.id}/reportar_fallo", params: { motivo_fallo: 'nadie en casa' }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok)
    fallo = ActionMailer::Base.deliveries.find { |m| m.to.first == 'uno@gmail.com' }
    expect(fallo).to be_present
    expect(fallo.body.encoded).to match(/problema|administración/i)
  end
end
