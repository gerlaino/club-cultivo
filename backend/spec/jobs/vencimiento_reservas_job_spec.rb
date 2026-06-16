require 'rails_helper'

RSpec.describe VencimientoReservasJob do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)     { create(:lote, club: club, sala: sala) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }
  let!(:stock)   { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100) }

  def reserva(fecha:, cantidad: 10)
    r = Reserva.new(club: club, paciente: paciente, user: admin, stock: stock,
                    cantidad: cantidad, fecha_entrega_estimada: fecha)
    r.save!(validate: false)
    r
  end

  it 'vence las reservas pasadas de fecha + gracia y libera el stock' do
    vencida = reserva(fecha: Date.current - Reserva::DIAS_VENCIMIENTO - 1)
    expect(stock.reload.gramos_reservados).to eq(10.0)

    described_class.new.perform

    expect(vencida.reload.estado).to eq('vencida')
    expect(stock.reload.gramos_reservados).to eq(0.0)
    expect(AlertaInterna.where(tipo: 'reserva_vencida').count).to eq(1)
  end

  it 'no vence una reserva reciente dentro de la gracia' do
    r = reserva(fecha: Date.current - 1)
    described_class.new.perform
    expect(r.reload.estado).to eq('pendiente')
  end

  it 'avisa de las reservas que se entregan hoy, sin duplicar' do
    reserva(fecha: Date.current)
    described_class.new.perform
    described_class.new.perform # idempotente el mismo día
    expect(AlertaInterna.where(tipo: 'reserva_por_entregar').count).to eq(1)
  end
end
