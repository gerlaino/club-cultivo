require 'rails_helper'

RSpec.describe 'Dispensación — descuentos y crédito por medio de pago', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:disp)     { create(:user, club: club, role: 'dispensador') }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:sala)     { create(:sala, club: club, created_by: admin) }
  let(:lote)     { create(:lote, club: club, sala: sala) }
  let(:paciente) { create(:paciente, club: club, created_by: admin, descuento_porcentaje: 10) }
  let!(:cc) do
    CuentaCorriente.create!(paciente: paciente, club: club, saldo_disponible: 0, limite_credito: 50_000)
  end
  let!(:stock) do
    Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca',
                  unidad: 'g', cantidad: 500, precio_sugerido_ars: 1000)
  end

  def dispensar(user: admin, **params)
    sign_in_as(user)
    post "/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { stock_id: stock.id, cantidad: 10, fecha_dispensacion: Time.zone.today.to_s }.merge(params) },
         headers: auth_headers, as: :json
  end

  context 'descuento del paciente (autoritativo en server)' do
    it 'lo aplica aunque el cliente no lo mande' do
      dispensar(medio_pago: 'efectivo')
      expect(response).to have_http_status(:created)
      d = Dispensacion.last
      # base 1000*10 = 10000, -10% socio = 9000
      expect(d.descuento_paciente_pct.to_f).to eq(10.0)
      expect(d.aporte_socio_ars.to_f).to eq(9000.0)
    end
  end

  context 'descuentos aditivos (paciente + dispensa)' do
    it 'suma ambos y aplica el total' do
      dispensar(medio_pago: 'efectivo', descuento_dispensa_pct: 15)
      d = Dispensacion.last
      expect(d.descuento_paciente_pct.to_f).to eq(10.0)
      expect(d.descuento_dispensa_pct.to_f).to eq(15.0)
      # base 10000, -25% = 7500
      expect(d.aporte_socio_ars.to_f).to eq(7500.0)
    end
  end

  context 'crédito según medio de pago' do
    it 'NO topea por crédito cuando paga en efectivo (aunque supere el límite)' do
      # base 100000 > limite 50000, pero efectivo no consume crédito
      dispensar(medio_pago: 'efectivo', cantidad: 100)
      expect(response).to have_http_status(:created)
    end

    it 'cuenta corriente que excede el crédito NO bloquea: hace split (crédito + efectivo)' do
      dispensar(medio_pago: 'cuenta_corriente', cantidad: 100) # total 90000, crédito disp 50000
      expect(response).to have_http_status(:created)
      d = Dispensacion.last
      expect(d.aporte_socio_ars.to_f).to eq(90000.0)
      expect(d.monto_credito_ars.to_f).to eq(50000.0)            # cae al crédito el disponible
      expect(cc.reload.saldo_disponible.to_f).to eq(-50000.0)    # solo se debita el crédito
      # dos asientos: deuda (crédito) + ingreso (efectivo)
      montos = d.movimientos_contables.pluck(:monto_ars).map(&:to_f).sort
      expect(montos).to eq([40000.0, 50000.0])
      expect(d.movimientos_contables.find_by(pagado: true).monto_ars.to_f).to eq(40000.0)
    end

    it 'no_abona SÍ bloquea cuando excede (no paga diferencia)' do
      dispensar(medio_pago: 'no_abona', cantidad: 100)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'permite cuenta corriente dentro del crédito disponible' do
      dispensar(medio_pago: 'cuenta_corriente', cantidad: 10) # 9000 <= 50000
      expect(response).to have_http_status(:created)
      expect(cc.reload.saldo_disponible.to_f).to eq(-9000.0)
      expect(Dispensacion.last.monto_credito_ars.to_f).to eq(9000.0)
    end
  end

  context 'override del aporte' do
    it 'admin puede pisar el total a mano' do
      dispensar(medio_pago: 'efectivo', aporte_socio_ars: 1234, user: admin)
      expect(Dispensacion.last.aporte_socio_ars.to_f).to eq(1234.0)
    end

    it 'dispensador NO puede pisar el total (server recalcula)' do
      dispensar(medio_pago: 'efectivo', aporte_socio_ars: 1, user: disp)
      expect(Dispensacion.last.aporte_socio_ars.to_f).to eq(9000.0)
    end
  end
end
