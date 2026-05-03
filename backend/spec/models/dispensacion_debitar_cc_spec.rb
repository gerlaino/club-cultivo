require 'rails_helper'

RSpec.describe 'Dispensacion#debitar_cuenta_corriente', type: :model do
  let(:club)    { create(:club) }
  let(:admin)   { create(:user, :admin, club: club) }
  let(:sede)    { create(:sede, club: club, created_by: admin) }
  let(:sala)    { create(:sala, club: club, created_by: admin) }
  let(:lote)    { create(:lote, club: club, sala: sala) }
  let(:paciente){ create(:paciente, club: club, created_by: admin) }

  let(:stock) do
    Stock.create!(
      sede: sede, lote: lote,
      origen: 'lote', forma_producto: 'flor_seca',
      unidad: 'g', cantidad: 200
    )
  end

  def crear_dispensacion(aporte:)
    Dispensacion.create!(
      paciente: paciente,
      user:     admin,
      stock:    stock,
      cantidad: 5,
      aporte_socio_ars: aporte
    )
  end

  context 'paciente con CuentaCorriente y aporte_socio_ars > 0' do
    let!(:cc) do
      CuentaCorriente.create!(
        paciente: paciente, club: club,
        saldo_disponible: 500, limite_credito: 500
      )
    end

    it 'decrementa el saldo disponible' do
      crear_dispensacion(aporte: 150)
      expect(cc.reload.saldo_disponible).to eq(350.0)
    end

    it 'crea un movimiento de debito' do
      dispensacion = crear_dispensacion(aporte: 150)
      expect(cc.movimientos.count).to eq(1)
      mov = cc.movimientos.first
      expect(mov.tipo).to eq('debito')
      expect(mov.monto.to_f).to eq(-150.0)
    end

    it 'el movimiento referencia la dispensacion' do
      dispensacion = crear_dispensacion(aporte: 150)
      expect(cc.movimientos.first.dispensacion).to eq(dispensacion)
    end

    it 'el movimiento registra el saldo antes y después' do
      crear_dispensacion(aporte: 200)
      mov = cc.movimientos.first
      expect(mov.saldo_anterior.to_f).to eq(500.0)
      expect(mov.saldo_nuevo.to_f).to eq(300.0)
    end

    it 'el usuario que dispensó queda como created_by del movimiento' do
      crear_dispensacion(aporte: 100)
      expect(cc.movimientos.first.created_by).to eq(admin)
    end
  end

  context 'aporte_socio_ars == 0' do
    let!(:cc) do
      CuentaCorriente.create!(
        paciente: paciente, club: club,
        saldo_disponible: 500, limite_credito: 500
      )
    end

    it 'no modifica el saldo' do
      crear_dispensacion(aporte: 0)
      expect(cc.reload.saldo_disponible).to eq(500.0)
    end

    it 'no crea movimientos' do
      crear_dispensacion(aporte: 0)
      expect(cc.movimientos.count).to eq(0)
    end
  end

  context 'paciente sin CuentaCorriente' do
    it 'no lanza error al dispensar con aporte > 0' do
      expect { crear_dispensacion(aporte: 100) }.not_to raise_error
    end

    it 'la dispensacion se crea igualmente' do
      expect { crear_dispensacion(aporte: 0) }
        .to change { Dispensacion.count }.by(1)
    end
  end

  context 'transaccionalidad' do
    let!(:cc) do
      CuentaCorriente.create!(
        paciente: paciente, club: club,
        saldo_disponible: 500, limite_credito: 500
      )
    end

    it 'no queda en estado inconsistente si el movimiento falla' do
      allow_any_instance_of(CuentaCorrienteMovimiento).to receive(:save!).and_raise(ActiveRecord::RecordInvalid)
      expect { crear_dispensacion(aporte: 100) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(Dispensacion.count).to eq(0)
      expect(cc.reload.saldo_disponible).to eq(500.0)
    end
  end
end
