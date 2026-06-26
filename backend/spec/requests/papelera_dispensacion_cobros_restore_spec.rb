require 'rails_helper'

# Fase 3 (cierre) — restauración de una dispensación con COBROS PARTIDOS (pago mixto):
# re-crea cada línea de cobro con su asiento/débito, validando el cupo de cuenta corriente actual.
RSpec.describe 'Papelera — restaurar dispensación con cobros partidos', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)     { create(:lote, club: club, sala: sala) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }
  let!(:cc)      { create(:cuenta_corriente, paciente: paciente, club: club, saldo_disponible: 0, limite_credito: 80_000) }
  # precio tal que aporte = 100.000 con cantidad 1
  let!(:stock)   { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 1000, precio_sugerido_ars: 100_000) }

  before { sign_in_as(admin) }

  # 40.000 en efectivo + el resto (60.000) cae a cuenta corriente → dispensa mixta (2 cobros).
  def crear_mixta
    post "/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { stock_id: stock.id, cantidad: 1, cobros: [{ medio: 'efectivo', monto: 40_000 }] } },
         headers: auth_headers, as: :json
    Dispensacion.last
  end

  it 're-aplica los cobros (efectivo + cuenta corriente) y el stock al restaurar' do
    d = crear_mixta
    expect(stock.reload.cantidad.to_f).to eq(999.0)
    expect(cc.reload.saldo_disponible.to_f).to eq(-60_000.0)

    delete "/dispensaciones/#{d.id}", headers: auth_headers, as: :json
    expect(stock.reload.cantidad.to_f).to eq(1000.0)
    expect(cc.reload.saldo_disponible.to_f).to eq(0.0)
    expect(Dispensacion.where(id: d.id)).to be_empty

    post '/papelera/restaurar', params: { tipo: 'dispensacion', id: d.id }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(stock.reload.cantidad.to_f).to eq(999.0)            # stock re-descontado
    expect(cc.reload.saldo_disponible.to_f).to eq(-60_000.0)  # cuenta corriente re-debitada
    expect(d.reload.cobros.count).to eq(2)                     # efectivo + cuenta corriente (frescos)
  end

  it 'bloquea si el cupo ya no alcanza para la parte a cuenta corriente' do
    d = crear_mixta
    delete "/dispensaciones/#{d.id}", headers: auth_headers, as: :json
    cc.update!(limite_credito: 10_000)  # < 60.000 necesarios

    post '/papelera/restaurar', params: { tipo: 'dispensacion', id: d.id }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['conflictos'].map { |c| c['codigo'] }).to include('credito_insuficiente')
    expect(Dispensacion.where(id: d.id)).to be_empty
  end
end
