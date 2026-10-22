require 'rails_helper'
require 'rake'

# AC (22-oct-2026, Germán): corregir desde acá los stocks con más en la mesa que en el frasco, «sin
# quilombos con dispensas ni plata». El total manda: la mesa baja hasta el total con su movimiento;
# en seco no escribe; con la caja del mostrador abierta se saltea; no toca dispensas ni plata; correrlo
# dos veces no cambia nada.
RSpec.describe 'rake stocks:mesa_de_mas' do
  before(:all) { Rails.application.load_tasks if Rake::Task.tasks.none? { |t| t.name == 'stocks:mesa_de_mas' } }

  let(:club)  { create(:club) }
  let!(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'social') }
  let(:stock) { create(:stock, :externo, club: club, sede: sede, cantidad: 53) }
  let!(:item) { ActsAsTenant.with_tenant(club) { MostradorItem.create!(club: club, mostrador: sede.mostrador!, stock: stock, cantidad: 115) } }

  def correr(corregir:)
    ENV['CORREGIR'] = corregir ? '1' : nil
    Rake::Task['stocks:mesa_de_mas'].reenable
    out = StringIO.new
    $stdout = out
    Rake::Task['stocks:mesa_de_mas'].invoke
    out.string
  ensure
    $stdout = STDOUT
    ENV.delete('CORREGIR')
  end

  it 'en seco dice qué haría y no escribe' do
    expect(correr(corregir: false)).to include('mesa 115.0 → 53.0')
    expect(item.reload.cantidad.to_f).to eq(115.0)
  end

  it 'con CORREGIR=1 baja la mesa al total, con movimiento a nombre del admin, y el total no cambia' do
    correr(corregir: true)
    expect(item.reload.cantidad.to_f).to eq(53.0)
    expect(stock.reload.cantidad.to_f).to eq(53.0)
    mov = ActsAsTenant.with_tenant(club) { item.movimientos.order(:id).last }
    expect([mov.tipo, mov.cantidad.to_f, mov.usuario]).to eq(['ajuste', -62.0, admin])
    expect(mov.motivo).to include('se tomó el total como bueno')
    expect(mov.turno_mostrador_id).to be_nil
  end

  it 'no toca dispensas, cobros, cuenta corriente ni asientos' do
    tablas = -> { ActsAsTenant.without_tenant { [Dispensacion, Cobro, CuentaCorrienteMovimiento, MovimientoContable, StockMovimiento].map(&:count) } }
    expect { correr(corregir: true) }.not_to(change { tablas.call })
  end

  it 'con la caja del mostrador abierta se saltea' do
    disp = create(:user, :dispensador, club: club)
    ActsAsTenant.with_tenant(club) { Mostradores::AbrirCaja.call(mostrador: sede.mostrador!, usuario: disp, efectivo_contado_ars: 0) }
    expect(correr(corregir: true)).to include('SE SALTEA')
    expect(item.reload.cantidad.to_f).to eq(115.0)
  end

  it 'correrlo dos veces no cambia nada la segunda' do
    correr(corregir: true)
    expect(correr(corregir: true)).to include('Ningún stock')
    expect(ActsAsTenant.with_tenant(club) { item.movimientos.count }).to eq(1)
  end
end
