require 'rails_helper'

# El débito a cuenta corriente ya no ocurre en el modelo (after_create eliminado
# para evitar doble débito). Ahora lo maneja DispensacionesController dentro de
# una transacción. Estos tests validan el flujo completo vía la API.
RSpec.describe 'Dispensacion debitar cuenta corriente', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:sala)     { create(:sala, club: club, created_by: admin) }
  let(:lote)     { create(:lote, club: club, sala: sala) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }
  let!(:cc) do
    CuentaCorriente.create!(
      paciente: paciente, club: club,
      saldo_disponible: 500, limite_credito: 500
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

  def dispensar(aporte:, cantidad: 5)
    post "/pacientes/#{paciente.id}/dispensaciones",
         params: {
           dispensacion: {
             stock_id:         stock.id,
             cantidad:         cantidad,
             aporte_socio_ars: aporte,
             medio_pago:       'cuenta_corriente',
             fecha_dispensacion: Time.zone.today.to_s,
           }
         },
         headers: auth_headers,
         as: :json
  end

  context 'paciente con CuentaCorriente y aporte_socio_ars > 0' do
    it 'decrementa el saldo disponible' do
      dispensar(aporte: 150)
      expect(response).to have_http_status(:created)
      expect(cc.reload.saldo_disponible).to eq(350.0)
    end

    it 'crea un movimiento de debito' do
      dispensar(aporte: 150)
      expect(cc.movimientos.count).to eq(1)
      mov = cc.movimientos.first
      expect(mov.tipo).to eq('debito')
      expect(mov.monto.to_f).to eq(-150.0)
    end

    it 'el movimiento referencia la dispensacion' do
      dispensar(aporte: 150)
      dispensacion = Dispensacion.last
      expect(cc.movimientos.first.dispensacion).to eq(dispensacion)
    end

    it 'el movimiento registra el saldo antes y después' do
      dispensar(aporte: 200)
      mov = cc.movimientos.first
      expect(mov.saldo_anterior.to_f).to eq(500.0)
      expect(mov.saldo_nuevo.to_f).to eq(300.0)
    end

    it 'el usuario que dispensó queda como created_by del movimiento' do
      dispensar(aporte: 100)
      expect(cc.movimientos.first.created_by).to eq(admin)
    end

    it 'no genera doble débito (idempotencia del guard)' do
      dispensar(aporte: 100)
      expect(cc.movimientos.where(tipo: 'debito').count).to eq(1)
      expect(cc.reload.saldo_disponible).to eq(400.0)
    end
  end

  context 'aporte_socio_ars == 0' do
    it 'no modifica el saldo' do
      dispensar(aporte: 0)
      expect(cc.reload.saldo_disponible).to eq(500.0)
    end

    it 'no crea movimientos' do
      dispensar(aporte: 0)
      expect(cc.movimientos.count).to eq(0)
    end
  end

  context 'paciente sin CuentaCorriente' do
    let(:paciente_sin_cc) { create(:paciente, club: club, created_by: admin) }

    it 'no lanza error al dispensar con efectivo' do
      post "/pacientes/#{paciente_sin_cc.id}/dispensaciones",
           params: {
             dispensacion: {
               stock_id:           stock.id,
               cantidad:           5,
               aporte_socio_ars:   100,
               medio_pago:         'efectivo',
               fecha_dispensacion: Time.zone.today.to_s,
             }
           },
           headers: auth_headers,
           as: :json
      expect(response).to have_http_status(:created)
    end

    it 'rechaza cuenta_corriente si no hay CC configurada' do
      post "/pacientes/#{paciente_sin_cc.id}/dispensaciones",
           params: {
             dispensacion: {
               stock_id:           stock.id,
               cantidad:           5,
               aporte_socio_ars:   100,
               medio_pago:         'cuenta_corriente',
               fecha_dispensacion: Time.zone.today.to_s,
             }
           },
           headers: auth_headers,
           as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  context 'transaccionalidad' do
    it 'si la dispensacion falla, no se debita la CC' do
      saldo_original = cc.saldo_disponible
      # cantidad > stock disponible → RecordInvalid en el save!
      dispensar(aporte: 100, cantidad: 9999)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(cc.reload.saldo_disponible).to eq(saldo_original)
      expect(cc.movimientos.count).to eq(0)
    end
  end
end
