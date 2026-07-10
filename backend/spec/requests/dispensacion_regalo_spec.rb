require 'rails_helper'

RSpec.describe 'Dispensacion regalo (entrega gratis)', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:sala)     { create(:sala, club: club, created_by: admin) }
  let(:lote)     { create(:lote, club: club, sala: sala) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }
  let!(:stock) do
    Stock.create!(
      sede: sede, lote: lote,
      origen: 'lote', forma_producto: 'flor_seca',
      unidad: 'g', cantidad: 100, precio_sugerido_ars: 1000
    )
  end

  before { sign_in_as(admin) }

  def regalar(cantidad: 5)
    post "/pacientes/#{paciente.id}/dispensaciones",
         params: {
           dispensacion: {
             stock_id:           stock.id,
             cantidad:           cantidad,
             es_regalo:          true,
             fecha_dispensacion: Date.today.to_s,
           }
         },
         headers: auth_headers,
         as: :json
  end

  context 'dispensación marcada como regalo' do
    it 'devuelve 201 aunque el aporte sea 0' do
      regalar
      expect(response).to have_http_status(:created)
    end

    it 'guarda es_regalo y medio_pago regalo con aporte 0' do
      regalar
      d = Dispensacion.last
      expect(d.es_regalo).to be(true)
      expect(d.medio_pago).to eq('regalo')
      expect(d.aporte_socio_ars.to_f).to eq(0.0)
    end

    it 'igual descuenta el stock (el producto sale)' do
      regalar(cantidad: 5)
      expect(stock.reload.cantidad.to_f).to eq(95.0)
    end

    it 'no genera ingreso contable (es gratis)' do
      expect { regalar }.not_to change {
        club.movimientos_contables.where(tipo: 'ingreso').count
      }
    end

    it 'no toca la cuenta corriente del paciente' do
      cc = CuentaCorriente.create!(paciente: paciente, club: club,
                                   saldo_disponible: 0, limite_credito: 5000)
      expect { regalar }.not_to change { cc.reload.movimientos.count }
    end
  end
end
