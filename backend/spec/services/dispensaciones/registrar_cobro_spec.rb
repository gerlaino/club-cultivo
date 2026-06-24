require 'rails_helper'

RSpec.describe Dispensaciones::RegistrarCobro do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }
  let!(:stock) { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 1000, precio_sugerido_ars: 100) }

  # Dispensa de $100.000 (saldo pendiente total al no tener cobros aún)
  let(:dispensacion) do
    Dispensacion.create!(paciente: paciente, user: admin, stock: stock, sede: sede,
                         cantidad: 5, medio_pago: 'efectivo', aporte_socio_ars: 100_000,
                         fecha_dispensacion: Date.current)
  end

  def registrar(medio:, monto:, **extra)
    described_class.call(dispensacion: dispensacion, club: club, usuario: admin,
                         medio: medio, monto: monto, **extra)
  end

  context 'cobro en efectivo' do
    it 'crea el cobro pagado y un asiento de ingreso, sin tocar la cuenta corriente' do
      res = registrar(medio: 'efectivo', monto: 40_000)
      expect(res.ok?).to be true
      expect(res.cobro.pagado).to be true
      expect(dispensacion.reload.saldo_pendiente).to eq(60_000)
      mov = dispensacion.movimientos_contables.last
      expect(mov.pagado).to be true
      expect(mov.categoria).to eq('dispensacion')
      expect(mov.paciente_id).to eq(paciente.id)
    end
  end

  context 'tu ejemplo: $100.000, cupo $80.000, paga $40.000 y el resto a cuenta' do
    let!(:cc) { create(:cuenta_corriente, paciente: paciente, club: club, saldo_disponible: 0, limite_credito: 80_000) }

    it 'permite el efectivo y deja el resto ($60.000) en cuenta corriente' do
      expect(registrar(medio: 'efectivo', monto: 40_000).ok?).to be true
      res = registrar(medio: 'cuenta_corriente', monto: 60_000)
      expect(res.ok?).to be true
      expect(res.cobro.pagado).to be false
      expect(dispensacion.reload.saldo_pendiente).to eq(0)
      expect(cc.reload.saldo_disponible).to eq(-60_000)   # deuda
    end
  end

  context 'bloqueos' do
    it 'bloquea cuenta corriente si el resto supera el cupo' do
      create(:cuenta_corriente, paciente: paciente, club: club, saldo_disponible: 0, limite_credito: 80_000)
      res = registrar(medio: 'cuenta_corriente', monto: 100_000)   # > cupo 80.000
      expect(res.ok?).to be false
      expect(res.error).to match(/cupo|insuficiente/i)
      expect(dispensacion.reload.cobros).to be_empty
    end

    it 'bloquea cuenta corriente si el socio no tiene cuenta habilitada' do
      res = registrar(medio: 'cuenta_corriente', monto: 50_000)
      expect(res.ok?).to be false
      expect(res.error).to match(/no tiene cuenta corriente/i)
    end

    it 'bloquea un cobro que supera el saldo pendiente' do
      res = registrar(medio: 'efectivo', monto: 120_000)
      expect(res.ok?).to be false
      expect(res.error).to match(/supera el saldo pendiente/i)
    end
  end

  context 'transferencia con comprobante' do
    it 'adjunta la foto del comprobante al cobro' do
      res = registrar(medio: 'transferencia', monto: 100_000,
                      comprobante: { io: StringIO.new('fake-img'), filename: 'comp.png', content_type: 'image/png' })
      expect(res.ok?).to be true
      expect(res.cobro.comprobante).to be_attached
    end
  end
end
