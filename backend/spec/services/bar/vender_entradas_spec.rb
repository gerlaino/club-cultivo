require 'rails_helper'

RSpec.describe Bar::VenderEntradas, type: :service do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin, tipo: 'mixta') }
  let(:bar)   { club.bares.create!(sede: sede, nombre: 'La Terraza') }
  let(:evento){ bar.eventos_bar.create!(club: club, nombre: 'Fiesta', fecha: Date.current) }
  let(:tipo)  { evento.tipos_entrada.create!(club: club, nombre: 'General', precio_ars: 4_500, cupo: 100) }

  before { ActsAsTenant.current_tenant = club }
  after  { ActsAsTenant.current_tenant = nil }

  it 'no vende entradas si el evento está finalizado o cancelado' do
    evento.update!(estado: 'finalizado')
    expect { described_class.new(tipo, admin, cantidad: 1).call }
      .to raise_error(ArgumentError, /finalizado/)
  end

  it 'crea las entradas con código único y descuenta del cupo' do
    entradas = described_class.new(tipo, admin, cantidad: 3, comprador: 'Rocío').call
    expect(entradas.size).to eq(3)
    expect(entradas.map(&:codigo).uniq.size).to eq(3)
    expect(tipo.reload.vendidas).to eq(3)
    expect(tipo.disponibles).to eq(97)
  end

  it 'agrega el ingreso en el libro (vendidas * precio) etiquetado con el evento' do
    described_class.new(tipo, admin, cantidad: 4).call
    mov = tipo.reload.movimiento_contable
    expect(mov.monto_ars).to eq(4 * 4_500)
    expect(mov.evento_bar_id).to eq(evento.id)
    expect(mov.tipo).to eq('ingreso')
  end

  it 'actualiza el mismo movimiento en una segunda venta (no duplica asientos)' do
    described_class.new(tipo, admin, cantidad: 2).call
    expect {
      described_class.new(tipo, admin, cantidad: 3).call
    }.not_to change { club.movimientos_contables.where(evento_bar_id: evento.id).count }
    expect(tipo.reload.movimiento_contable.monto_ars).to eq(5 * 4_500)
  end

  it 'no permite vender más que el cupo' do
    chico = evento.tipos_entrada.create!(club: club, nombre: 'VIP', precio_ars: 9_000, cupo: 2)
    expect { described_class.new(chico, admin, cantidad: 5).call }.to raise_error(ArgumentError, /quedan/)
    expect(chico.reload.vendidas).to eq(0)
  end

  it 'break_even_entradas = costos comprometidos / precio promedio' do
    tipo # general 4500
    evento.costos.create!(club: club, created_by: admin, concepto: 'DJ', monto_ars: 90_000)
    expect(evento.reload.break_even_entradas).to eq(20) # 90000 / 4500
  end
end
