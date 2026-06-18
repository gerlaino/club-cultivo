require 'rails_helper'

RSpec.describe 'PATCH /dispensaciones/:id — edición con reversa', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)     { create(:lote, club: club, sala: sala) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }
  let!(:cc)      { CuentaCorriente.create!(paciente: paciente, club: club, saldo_disponible: 0, limite_credito: 100_000) }
  let!(:stock)   { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100, precio_sugerido_ars: 100) }

  before { sign_in_as(admin) }

  def crear(params)
    post "/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { stock_id: stock.id, cantidad: 10, fecha_dispensacion: Date.today.to_s }.merge(params) },
         headers: auth_headers, as: :json
    Dispensacion.last
  end

  context 'editar cantidad (efectivo)' do
    it 'reajusta el stock al delta correcto' do
      d = crear(medio_pago: 'efectivo')               # stock 100 -> 90
      expect(stock.reload.cantidad.to_f).to eq(90.0)
      patch "/dispensaciones/#{d.id}", params: { dispensacion: { cantidad: 20, aporte_socio_ars: 2000 } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(stock.reload.cantidad.to_f).to eq(80.0)  # 100 - 20
      expect(d.reload.cantidad.to_f).to eq(20.0)
      expect(d.aporte_socio_ars.to_f).to eq(2000.0)
    end

    it 'rechaza si la cantidad nueva supera el disponible' do
      d = crear(medio_pago: 'efectivo')
      patch "/dispensaciones/#{d.id}", params: { dispensacion: { cantidad: 999, aporte_socio_ars: 100 } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(stock.reload.cantidad.to_f).to eq(90.0)  # sin cambios (rollback)
    end
  end

  context 'editar dispensación a crédito (cuenta corriente)' do
    it 'revierte el débito viejo y aplica el nuevo' do
      d = crear(medio_pago: 'cuenta_corriente')        # aporte 1000 -> CC -1000
      expect(cc.reload.saldo_disponible.to_f).to eq(-1000.0)
      patch "/dispensaciones/#{d.id}", params: { dispensacion: { cantidad: 20, aporte_socio_ars: 2000 } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(cc.reload.saldo_disponible.to_f).to eq(-2000.0)
      expect(d.reload.monto_credito_ars.to_f).to eq(2000.0)
    end
  end

  context 'edición no financiera (observaciones)' do
    it 'actualiza directo sin tocar stock' do
      d = crear(medio_pago: 'efectivo')
      patch "/dispensaciones/#{d.id}", params: { dispensacion: { observaciones: 'nota' } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(stock.reload.cantidad.to_f).to eq(90.0)
      expect(d.reload.observaciones).to eq('nota')
    end
  end
end
