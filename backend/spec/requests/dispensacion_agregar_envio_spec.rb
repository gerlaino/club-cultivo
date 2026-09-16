require 'rails_helper'

# AC (Germán, 16-sep-2026): una dispensa que salió sin tildar «con envío» se puede mandar por
# delivery después, sin anularla ni tocar lo cobrado.
RSpec.describe 'Dispensación: agregar envío después', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:delivery) { create(:user, club: club, role: 'delivery') }
  let(:sede)     { create(:sede, club: club, created_by: admin, tipo: 'mixta') }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)     { create(:lote, club: club, sala: sala) }
  let(:paciente) { create(:paciente, club: club, created_by: admin, telefono: '1122', domicilio_calle: 'Av. Siempreviva', domicilio_altura: '742', domicilio_ciudad: 'CABA') }
  let!(:stock)   { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100, precio_sugerido_ars: 100) }

  before { sign_in_as(admin) }

  def json = JSON.parse(response.body)

  def dispensar_sin_envio
    post "/api/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { stock_id: stock.id, cantidad: 5, medio_pago: 'efectivo', aporte_socio_ars: 500 } }, as: :json
    expect(response).to have_http_status(:created), response.body
    Dispensacion.find(json['id'])
  end

  it 'le agrega el paquete: repartidor, dirección elegida, contacto, código y estado pendiente' do
    d = dispensar_sin_envio
    expect(d.con_envio).to be(false)

    patch "/api/dispensaciones/#{d.id}/agregar_envio",
          params: { dispensacion: { delivery_id: delivery.id, direccion_origen: 'domicilio', notas_envio: 'tocar timbre' } }, as: :json

    expect(response).to have_http_status(:ok), response.body
    d.reload
    expect(d.con_envio).to        be(true)
    expect(d.delivery_id).to      eq(delivery.id)
    expect(d.estado_envio).to     eq('pendiente')
    expect(d.codigo_paquete).to   start_with('PKG-')
    expect(d.direccion_envio).to  eq('Av. Siempreviva 742, CABA')
    expect(d.contacto_nombre).to  eq(paciente.nombre_completo)
    expect(d.historial_envio.last['evento']).to eq('envio_agregado')
  end

  it 'lo cobrado no se toca' do
    d = dispensar_sin_envio
    cobros_antes = d.cobros.count
    monto_antes  = d.aporte_socio_ars

    patch "/api/dispensaciones/#{d.id}/agregar_envio",
          params: { dispensacion: { delivery_id: delivery.id, direccion_origen: 'domicilio' } }, as: :json

    d.reload
    expect(d.cobros.count).to     eq(cobros_antes)
    expect(d.aporte_socio_ars).to eq(monto_antes)
    expect(d.cobrar_en_entrega).to be(false)
  end

  it 'el repartidor lo ve en su lista' do
    d = dispensar_sin_envio
    patch "/api/dispensaciones/#{d.id}/agregar_envio",
          params: { dispensacion: { delivery_id: delivery.id, direccion_origen: 'domicilio' } }, as: :json

    sign_in_as(delivery)
    get '/api/dispensaciones/mis_paquetes'

    expect(json['dispensaciones'].map { |p| p['id'] }).to include(d.id)
  end

  it 'una que ya va por delivery no se vuelve a agregar' do
    d = dispensar_sin_envio
    patch "/api/dispensaciones/#{d.id}/agregar_envio", params: { dispensacion: { delivery_id: delivery.id, direccion_origen: 'domicilio' } }, as: :json
    patch "/api/dispensaciones/#{d.id}/agregar_envio", params: { dispensacion: { delivery_id: delivery.id, direccion_origen: 'domicilio' } }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'una dirección que el paciente no tiene rebota con el motivo, y nada cambia' do
    d = dispensar_sin_envio
    patch "/api/dispensaciones/#{d.id}/agregar_envio", params: { dispensacion: { delivery_id: delivery.id, direccion_origen: 'envio' } }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(d.reload.con_envio).to be(false)
  end

  it 'sin el add-on de Delivery no existe' do
    d = dispensar_sin_envio
    club.update!(features: club.features.merge('delivery' => false))

    patch "/api/dispensaciones/#{d.id}/agregar_envio", params: { dispensacion: { delivery_id: delivery.id, direccion_origen: 'domicilio' } }, as: :json

    expect(response).to have_http_status(:forbidden)
  end
end
