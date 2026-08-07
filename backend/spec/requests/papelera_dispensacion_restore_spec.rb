require 'rails_helper'

# Fase 3 — restauración COMPLETA de una dispensación: re-aplica stock + asiento contable +
# débito de cuenta corriente, validando contra el estado actual (bloquea si el crédito ya se
# consumió). Comparte la lógica financiera con la creación (Dispensaciones::AplicarEfectos).
RSpec.describe 'Papelera — restauración de dispensación', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)     { create(:lote, club: club, sala: sala) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }
  let!(:cc)      { CuentaCorriente.create!(paciente: paciente, club: club, saldo_disponible: 0, limite_credito: 100_000) }
  let!(:stock)   { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100, precio_sugerido_ars: 100) }

  before { sign_in_as(admin) }

  def crear_dispensacion(medio: 'efectivo')
    post "/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { stock_id: stock.id, cantidad: 10, fecha_dispensacion: Time.zone.today.to_s, medio_pago: medio } },
         headers: auth_headers, as: :json
    Dispensacion.last
  end

  it 're-aplica stock y asiento contable al restaurar (efectivo)' do
    d = crear_dispensacion(medio: 'efectivo')
    expect(stock.reload.cantidad.to_f).to eq(90.0)

    delete "/dispensaciones/#{d.id}", headers: auth_headers, as: :json
    expect(stock.reload.cantidad.to_f).to eq(100.0)        # borrado → stock devuelto
    expect(Dispensacion.where(id: d.id)).to be_empty       # soft-deleted

    post '/papelera/restaurar', params: { tipo: 'dispensacion', id: d.id }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok)

    expect(stock.reload.cantidad.to_f).to eq(90.0)         # restaurado → stock vuelto a descontar
    expect(Dispensacion.where(id: d.id)).to exist
    expect(d.reload.movimientos_contables.count).to eq(1)  # asiento fresco (sin duplicar)
  end

  it 'bloquea con motivo si el crédito ya no alcanza (crédito consumido tras el borrado)' do
    d = crear_dispensacion(medio: 'cuenta_corriente')      # 10g * $100 = $1000 a crédito
    expect(cc.reload.saldo_disponible.to_f).to eq(-1000.0)

    delete "/dispensaciones/#{d.id}", headers: auth_headers, as: :json
    expect(cc.reload.saldo_disponible.to_f).to eq(0.0)     # crédito revertido

    cc.update!(limite_credito: 500)                        # ahora solo dispone de $500

    post '/papelera/restaurar', params: { tipo: 'dispensacion', id: d.id }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['conflictos'].map { |c| c['codigo'] }).to include('credito_insuficiente')

    expect(Dispensacion.where(id: d.id)).to be_empty       # NO se restauró
    expect(stock.reload.cantidad.to_f).to eq(100.0)        # ni se tocó el stock
  end

  it 'bloquea si el stock no alcanza al restaurar' do
    d = crear_dispensacion(medio: 'efectivo')
    delete "/dispensaciones/#{d.id}", headers: auth_headers, as: :json
    stock.update!(cantidad: 5)                             # quedó poco stock

    post '/papelera/restaurar', params: { tipo: 'dispensacion', id: d.id }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['conflictos'].map { |c| c['codigo'] }).to include('stock_insuficiente')
  end
end
