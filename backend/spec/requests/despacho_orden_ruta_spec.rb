require 'rails_helper'

# La entrega es secuencial: el delivery solo puede cerrar (entregar/fallar) el
# despacho que es el siguiente sin resolver de su ruta (los que están en camino,
# por orden_entrega). No puede saltear paradas. El admin queda exento.
RSpec.describe 'Orden de entrega secuencial', type: :request do
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
  let!(:stock) { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 1000, precio_sugerido_ars: 100) }

  def crear_despacho(orden:)
    post "/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { stock_id: stock.id, cantidad: 5, medio_pago: 'efectivo', aporte_socio_ars: 500,
                                   con_envio: true, delivery_id: delivery.id, usar_domicilio_paciente: true } },
         headers: auth_headers
    expect(response).to have_http_status(:created)
    d = Dispensacion.last
    d.update_columns(estado_envio: 'en_viaje', orden_entrega: orden)
    d
  end

  let!(:parada1) { sign_in_as(dispensador); crear_despacho(orden: 1) }
  let!(:parada2) { crear_despacho(orden: 2) }
  let!(:parada3) { crear_despacho(orden: 3) }

  context 'cuando el delivery intenta saltear una parada' do
    before { delete '/api/users/sign_out'; sign_in_as(delivery) }

    it 'rechaza (422) entregar la 3ra cuando la 1ra y 2da siguen abiertas' do
      patch "/dispensaciones/#{parada3.id}/entregar", params: { notas_entrega: 'OK' }, headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(parada3.reload.estado_envio).to eq('en_viaje')
    end

    it 'rechaza (422) reportar fallo en la 2da cuando la 1ra sigue abierta' do
      patch "/dispensaciones/#{parada2.id}/reportar_fallo", params: { motivo_fallo: 'Nadie' }, headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(parada2.reload.estado_envio).to eq('en_viaje')
    end

    it 'permite cerrar en orden: 1ra entregada habilita la 2da' do
      patch "/dispensaciones/#{parada1.id}/entregar", params: { notas_entrega: 'OK' }, headers: auth_headers
      expect(response).to have_http_status(:ok)

      # Ahora la 2da es la siguiente
      patch "/dispensaciones/#{parada2.id}/entregar", params: { notas_entrega: 'OK' }, headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(parada2.reload.estado_envio).to eq('entregado')
    end

    it 'un fallido cuenta como resuelto y habilita la siguiente' do
      patch "/dispensaciones/#{parada1.id}/reportar_fallo", params: { motivo_fallo: 'Ausente' }, headers: auth_headers
      expect(response).to have_http_status(:ok)

      patch "/dispensaciones/#{parada2.id}/entregar", params: { notas_entrega: 'OK' }, headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(parada2.reload.estado_envio).to eq('entregado')
    end
  end

  context 'cuando es admin' do
    before { delete '/api/users/sign_out'; sign_in_as(admin) }

    it 'puede saltear el orden (cerrar la 3ra primero)' do
      patch "/dispensaciones/#{parada3.id}/entregar", params: { notas_entrega: 'OK' }, headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(parada3.reload.estado_envio).to eq('entregado')
    end
  end
end
