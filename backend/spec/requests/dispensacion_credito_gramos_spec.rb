require 'rails_helper'

RSpec.describe 'Dispensacion con credito_gramos', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:sala)     { create(:sala, club: club, created_by: admin) }
  let(:lote)     { create(:lote, club: club, sala: sala) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }
  let!(:cc) do
    CuentaCorriente.create!(
      paciente: paciente, club: club,
      saldo_disponible: 0, limite_credito: 0,
      credito_gramos_activo: true,
      saldo_disponible_g: 100.0,
      limite_credito_g:   100.0,
    )
  end
  let!(:stock) do
    Stock.create!(
      sede: sede, lote: lote,
      origen: 'lote', forma_producto: 'flor_seca',
      unidad: 'g', cantidad: 200
    )
  end

  before { sign_in_as(admin) }

  def dispensar(cantidad: 10, medio_pago: 'credito_gramos')
    post "/pacientes/#{paciente.id}/dispensaciones",
         params: {
           dispensacion: {
             stock_id:           stock.id,
             cantidad:           cantidad,
             aporte_socio_ars:   0,
             medio_pago:         medio_pago,
             fecha_dispensacion: Time.zone.today.to_s,
           }
         },
         headers: auth_headers,
         as: :json
  end

  context 'dispensación exitosa con credito_gramos' do
    it 'devuelve 201' do
      dispensar(cantidad: 10)
      expect(response).to have_http_status(:created)
    end

    it 'descuenta del saldo_disponible_g' do
      dispensar(cantidad: 10)
      expect(cc.reload.saldo_disponible_g.to_f).to eq(90.0)
    end

    it 'crea un movimiento de débito con el monto en gramos' do
      dispensar(cantidad: 10)
      mov = cc.movimientos.where(tipo: 'debito').last
      expect(mov).to be_present
      expect(mov.monto.to_f).to eq(-10.0)
      expect(mov.saldo_anterior.to_f).to eq(100.0)
      expect(mov.saldo_nuevo.to_f).to eq(90.0)
    end

    it 'el movimiento referencia la dispensacion' do
      dispensar(cantidad: 10)
      expect(cc.movimientos.last.dispensacion).to eq(Dispensacion.last)
    end

    it 'no genera doble débito (guard de idempotencia)' do
      dispensar(cantidad: 10)
      expect(cc.movimientos.where(tipo: 'debito').count).to eq(1)
      expect(cc.reload.saldo_disponible_g.to_f).to eq(90.0)
    end
  end

  context 'rechazos de validación' do
    it 'rechaza si el crédito en gramos no está activo' do
      cc.update!(credito_gramos_activo: false)
      dispensar(cantidad: 10)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/crédito en gramos/i)
    end

    it 'rechaza si el saldo en gramos es insuficiente' do
      cc.update!(saldo_disponible_g: 5.0)
      dispensar(cantidad: 10)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/gramos insuficientes/i)
    end

    it 'no modifica el saldo si la dispensacion falla por stock insuficiente' do
      dispensar(cantidad: 9999)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(cc.reload.saldo_disponible_g.to_f).to eq(100.0)
      expect(cc.movimientos.where(tipo: 'debito').count).to eq(0)
    end
  end

  context 'eliminación — reversa de gramos' do
    let!(:dispensacion) do
      dispensar(cantidad: 15)
      Dispensacion.last
    end

    it 'restaura el saldo_disponible_g al eliminar' do
      saldo_previo = cc.reload.saldo_disponible_g.to_f
      delete "/dispensaciones/#{dispensacion.id}", headers: auth_headers
      expect(response).to have_http_status(:no_content)
      expect(cc.reload.saldo_disponible_g.to_f).to eq(saldo_previo + 15.0)
    end

    it 'crea un movimiento de ajuste al revertir' do
      count_antes = cc.movimientos.count
      delete "/dispensaciones/#{dispensacion.id}", headers: auth_headers
      expect(cc.movimientos.count).to eq(count_antes + 1)
      expect(cc.movimientos.order(:created_at).last.tipo).to eq('ajuste')
    end
  end
end
