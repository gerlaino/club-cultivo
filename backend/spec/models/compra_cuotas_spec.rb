require 'rails_helper'

RSpec.describe CompraCuotas, type: :model do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }

  def nueva(attrs = {})
    CompraCuotas.create!({
      club: club, sede: sede, created_by: admin,
      descripcion: 'Aire acondicionado', categoria: 'mantenimiento',
      monto_total_ars: 600_000, cuotas_total: 6,
      fecha_primera_cuota: Date.new(2026, 5, 1),
    }.merge(attrs))
  end

  it 'genera N movimientos egreso, uno por mes desde la primera cuota' do
    compra = nueva
    movs = compra.movimientos_contables.order(:fecha)
    expect(movs.count).to eq(6)
    expect(movs.map(&:fecha)).to eq((0..5).map { |i| Date.new(2026, 5, 1) >> i })
    expect(movs.map(&:cuota_numero)).to eq([1, 2, 3, 4, 5, 6])
    expect(movs.all? { |m| m.tipo == 'egreso' && m.categoria == 'mantenimiento' }).to be(true)
  end

  it 'reparte el total en cuotas iguales y la última absorbe el redondeo' do
    compra = nueva(monto_total_ars: 100, cuotas_total: 3)
    montos = compra.movimientos_contables.order(:fecha).map { |m| m.monto_ars.to_f }
    expect(montos).to eq([33.33, 33.33, 33.34])
    expect(montos.sum.round(2)).to eq(100.0)
  end

  it 'permite cuotas con fecha futura (vencen adelante) y las marca no pagadas' do
    compra  = nueva(fecha_primera_cuota: Date.today, cuotas_total: 3)
    futuras = compra.movimientos_contables.select { |m| m.fecha > Date.today }
    expect(futuras).not_to be_empty
    expect(futuras.all?(&:valid?)).to be(true)
    expect(futuras.all? { |m| m.pagado == false }).to be(true)
  end

  it 'las cuotas pasadas quedan como pagadas' do
    compra = nueva(fecha_primera_cuota: (Date.today << 3), cuotas_total: 2)
    expect(compra.movimientos_contables.all?(&:pagado)).to be(true)
  end

  it 'al borrar la compra borra sus cuotas' do
    compra = nueva
    expect { compra.destroy }.to change(MovimientoContable, :count).by(-6)
  end
end
