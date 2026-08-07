require 'rails_helper'

RSpec.describe 'PATCH /dispensaciones/:id/cancelar_entrega', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)     { create(:lote, club: club, sala: sala) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }
  let!(:cc)      { CuentaCorriente.create!(paciente: paciente, club: club, saldo_disponible: 0, limite_credito: 100_000) }
  let!(:stock)   { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100, precio_sugerido_ars: 100) }

  before { sign_in_as(admin) }

  def crear_con_envio(medio: 'cuenta_corriente')
    post "/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { stock_id: stock.id, cantidad: 10, fecha_dispensacion: Time.zone.today.to_s, medio_pago: medio } },
         headers: auth_headers, as: :json
    Dispensacion.last
  end

  it 'cancela conservando el registro, revierte stock/CC y deja el evento en el historial' do
    d = crear_con_envio
    expect(stock.reload.cantidad.to_f).to eq(90.0)
    expect(cc.reload.saldo_disponible.to_f).to eq(-1000.0)

    patch "/dispensaciones/#{d.id}/cancelar_entrega", params: { motivo: 'el socio canceló' }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok)

    d.reload
    expect(d.estado_envio).to eq('cancelada')           # registro conservado
    expect(Dispensacion.exists?(d.id)).to be(true)
    expect(stock.reload.cantidad.to_f).to eq(100.0)     # producto devuelto
    expect(cc.reload.saldo_disponible.to_f).to eq(0.0)  # crédito revertido
    expect(d.movimientos_contables.count).to eq(0)      # asientos revertidos
    evento = d.historial_envio.last
    expect(evento['evento']).to eq('cancelado')
    expect(evento['motivo']).to eq('el socio canceló')
  end

  it 'una dispensación cancelada NO cuenta en el total dispensado del paciente' do
    d = crear_con_envio(medio: 'efectivo')
    expect(paciente.reload.dispensado_mes_actual_g).to eq(10.0)
    patch "/dispensaciones/#{d.id}/cancelar_entrega", headers: auth_headers, as: :json
    expect(paciente.reload.dispensado_mes_actual_g).to eq(0.0)
  end

  it 'no se puede cancelar dos veces' do
    d = crear_con_envio(medio: 'efectivo')
    patch "/dispensaciones/#{d.id}/cancelar_entrega", headers: auth_headers, as: :json
    patch "/dispensaciones/#{d.id}/cancelar_entrega", headers: auth_headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'reprogramar deja un evento en el historial' do
    d = crear_con_envio(medio: 'efectivo')
    d.update_columns(con_envio: true, estado_envio: 'en_viaje', delivery_id: admin.id,
                     envio_calle: 'Av', envio_altura: '1', envio_ciudad: 'CABA',
                     contacto_nombre: 'N', direccion_envio: 'Av 1, CABA')
    patch "/dispensaciones/#{d.id}/reportar_fallo", params: { motivo_fallo: 'nadie atendió' }, headers: auth_headers, as: :json
    patch "/dispensaciones/#{d.id}/reprogramar", headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok)
    eventos = d.reload.historial_envio.map { |e| e['evento'] }
    expect(eventos).to include('fallido', 'reprogramado')
  end
end
