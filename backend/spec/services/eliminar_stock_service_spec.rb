require 'rails_helper'

RSpec.describe EliminarStockService do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)     { create(:lote, club: club, sala: sala) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }
  let!(:stock) do
    Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100)
  end

  def dispensar(attrs = {})
    Dispensacion.create!({ paciente: paciente, user: admin, stock: stock, cantidad: 10,
                           fecha_dispensacion: Date.today, medio_pago: 'efectivo' }.merge(attrs))
  end

  it 'borra el stock arrastrando dispensaciones pendientes y sus movimientos' do
    d = dispensar
    expect(stock.reload.cantidad).to eq(90)

    described_class.new(stock: stock, usuario: admin).eliminar!

    expect(Stock.exists?(stock.id)).to be(false)
    expect(Dispensacion.exists?(d.id)).to be(false)
    expect(StockMovimiento.where(stock_id: stock.id)).to be_empty
  end

  it 'borra también las reservas pendientes sin seña' do
    r = Reserva.create!(club: club, paciente: paciente, stock: stock, user: admin,
                        cantidad: 5, estado: 'pendiente', fecha_entrega_estimada: Date.today + 3, sena_ars: 0)
    described_class.new(stock: stock, usuario: admin).eliminar!
    expect(Reserva.exists?(r.id)).to be(false)
  end

  it 'BLOQUEA si hay un despacho entregado' do
    d = dispensar
    d.update_column(:estado_envio, 'entregado')
    expect {
      described_class.new(stock: stock, usuario: admin).eliminar!
    }.to raise_error(EliminarStockService::Bloqueado, /entregados/)
    expect(Stock.exists?(stock.id)).to be(true)
  end

  it 'BLOQUEA si hay una reserva con seña' do
    Reserva.create!(club: club, paciente: paciente, stock: stock, user: admin,
                    cantidad: 5, estado: 'pendiente', fecha_entrega_estimada: Date.today + 3, sena_ars: 1000)
    expect {
      described_class.new(stock: stock, usuario: admin).eliminar!
    }.to raise_error(EliminarStockService::Bloqueado, /seña/)
  end
end
