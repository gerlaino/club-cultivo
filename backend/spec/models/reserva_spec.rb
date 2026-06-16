require 'rails_helper'

RSpec.describe Reserva, type: :model do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)     { create(:lote, club: club, sala: sala) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }

  let!(:stock) do
    Stock.create!(sede: sede, lote: lote, origen: 'lote',
                  forma_producto: 'flor_seca', unidad: 'g', cantidad: 100)
  end

  def nueva(attrs = {})
    Reserva.new({
      club: club, paciente: paciente, user: admin, stock: stock,
      cantidad: 10, fecha_entrega_estimada: 3.days.from_now.to_date,
    }.merge(attrs))
  end

  describe 'validaciones' do
    it 'es válida con datos correctos' do
      expect(nueva).to be_valid
    end

    it 'requiere cantidad > 0' do
      expect(nueva(cantidad: 0)).not_to be_valid
    end

    it 'requiere fecha_entrega_estimada' do
      expect(nueva(fecha_entrega_estimada: nil)).not_to be_valid
    end

    it 'no permite seña negativa' do
      expect(nueva(sena_ars: -10)).not_to be_valid
    end
  end

  describe 'bloqueo de stock' do
    it 'una reserva pendiente cuenta en gramos_reservados y baja el disponible real' do
      nueva(cantidad: 30).save!
      expect(stock.reload.gramos_reservados).to eq(30.0)
      expect(stock.cantidad_disponible_real).to eq(70.0)
    end

    it 'no permite reservar más que el disponible real (otra reserva ya bloqueó)' do
      nueva(cantidad: 80).save!
      segunda = nueva(cantidad: 30) # 80 + 30 > 100
      expect(segunda).not_to be_valid
      expect(segunda.errors[:cantidad]).to be_present
    end

    it 'una reserva entregada o cancelada deja de bloquear stock' do
      r = nueva(cantidad: 40)
      r.save!
      expect(stock.reload.gramos_reservados).to eq(40.0)
      r.cancelar!
      expect(stock.reload.gramos_reservados).to eq(0.0)
    end
  end

  describe '#aporte_restante_ars' do
    it 'es el total estimado menos la seña' do
      r = nueva(aporte_estimado_ars: 1000, sena_ars: 300)
      expect(r.aporte_restante_ars).to eq(700)
    end

    it 'nunca es negativo' do
      r = nueva(aporte_estimado_ars: 200, sena_ars: 500)
      expect(r.aporte_restante_ars).to eq(0)
    end
  end

  describe 'transiciones de estado' do
    it 'cancelar! sólo opera sobre pendientes' do
      r = nueva
      r.save!
      expect(r.cancelar!).to be_truthy
      expect(r.reload.estado).to eq('cancelada')
      expect(r.cancelar!).to be_falsey
    end

    it 'marcar_vencida! sólo opera sobre pendientes' do
      r = nueva
      r.save!
      expect(r.marcar_vencida!).to be_truthy
      expect(r.reload.estado).to eq('vencida')
    end
  end

  describe '.a_vencer' do
    it 'incluye sólo pendientes pasadas de fecha + días de gracia' do
      vieja  = nueva(fecha_entrega_estimada: (Date.current - Reserva::DIAS_VENCIMIENTO - 1))
      vieja.save!(validate: false)
      reciente = nueva(fecha_entrega_estimada: Date.current)
      reciente.save!
      expect(Reserva.a_vencer).to include(vieja)
      expect(Reserva.a_vencer).not_to include(reciente)
    end
  end
end
