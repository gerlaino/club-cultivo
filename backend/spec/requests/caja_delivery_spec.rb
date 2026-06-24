require 'rails_helper'

RSpec.describe 'Caja del delivery: efectivo en tránsito', type: :request do
  include AuthHelpers

  let(:club)        { create(:club) }
  let(:admin)       { create(:user, :admin, club: club) }
  let(:dispensador) { create(:user, :dispensador, club: club) }
  let(:delivery)    { create(:user, club: club, role: 'delivery') }
  let(:sede)        { create(:sede, club: club, created_by: admin) }
  let(:sala)        { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)        { create(:lote, club: club, sala: sala) }
  let(:paciente)    { create(:paciente, club: club, created_by: admin, telefono: '1', domicilio_calle: 'Calle', domicilio_ciudad: 'CABA') }
  let!(:stock) { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 1000, precio_sugerido_ars: 100_000) }

  it 'el efectivo de la entrega no se asienta hasta que el admin recibe la caja' do
    # 1) Contra-entrega: se crea sin cobros
    sign_in_as(dispensador)
    post "/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { stock_id: stock.id, cantidad: 1, cobrar_en_entrega: true,
                                   con_envio: true, delivery_id: delivery.id, usar_domicilio_paciente: true } },
         headers: auth_headers
    expect(response).to have_http_status(:created)
    d = Dispensacion.last

    # 2) El delivery entrega cobrando efectivo
    delete '/api/users/sign_out'
    sign_in_as(delivery)
    patch "/dispensaciones/#{d.id}/entregar",
          params: { cobros: [{ medio: 'efectivo', monto: 100_000 }], notas_entrega: 'OK' },
          headers: auth_headers
    expect(response).to have_http_status(:ok)

    cobro = d.cobros.find_by(medio: 'efectivo')
    expect(cobro.rendido).to be false                                   # en tránsito
    expect(d.movimientos_contables.where(medio_pago: 'efectivo')).to be_empty  # sin asiento aún

    # 3) El admin ve la caja y la recibe
    delete '/api/users/sign_out'
    sign_in_as(admin)
    get "/usuarios/#{delivery.id}/stats", headers: auth_headers
    expect(JSON.parse(response.body).dig('caja_delivery', 'efectivo_en_mano')).to eq(100_000)

    post "/usuarios/#{delivery.id}/recibir_caja", headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['recibido_ars']).to eq(100_000)

    expect(cobro.reload.rendido).to be true
    expect(d.movimientos_contables.where(medio_pago: 'efectivo')).to be_present  # asiento creado

    # ya no queda efectivo en mano
    get "/usuarios/#{delivery.id}/stats", headers: auth_headers
    expect(JSON.parse(response.body).dig('caja_delivery', 'efectivo_en_mano')).to eq(0)
  end

  it 'si entrega un admin (no el delivery), el efectivo se asienta en el acto' do
    sign_in_as(dispensador)
    post "/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { stock_id: stock.id, cantidad: 1, cobrar_en_entrega: true,
                                   con_envio: true, delivery_id: delivery.id, usar_domicilio_paciente: true } },
         headers: auth_headers
    d = Dispensacion.last

    # El ADMIN entrega y cobra efectivo → la plata entra a la caja del club
    delete '/api/users/sign_out'
    sign_in_as(admin)
    patch "/dispensaciones/#{d.id}/entregar",
          params: { cobros: [{ medio: 'efectivo', monto: 100_000 }], notas_entrega: 'OK' },
          headers: auth_headers
    expect(response).to have_http_status(:ok)

    cobro = d.cobros.find_by(medio: 'efectivo')
    expect(cobro.rendido).to be true                                  # NO queda en tránsito
    expect(d.movimientos_contables.where(medio_pago: 'efectivo')).to be_present  # asiento al instante
    get "/usuarios/#{delivery.id}/stats", headers: auth_headers
    expect(JSON.parse(response.body).dig('caja_delivery', 'efectivo_en_mano')).to eq(0)
  end
end
