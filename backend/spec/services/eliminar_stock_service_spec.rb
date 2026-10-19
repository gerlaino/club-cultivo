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
                           fecha_dispensacion: Time.zone.today, medio_pago: 'efectivo' }.merge(attrs))
  end

  # AC (Germán, 16-oct-2026): «si se hicieron dispensas no se debería poder eliminar el stock,
  # sólo dar de baja/finalizar».
  it 'BLOQUEA si tiene una dispensa, aunque sea pendiente de envío, y no toca nada' do
    d = dispensar
    expect {
      described_class.new(stock: stock, usuario: admin).eliminar!
    }.to raise_error(EliminarStockService::Bloqueado, /ya tiene dispensas.*finaliza/)
    expect(Stock.exists?(stock.id)).to be(true)
    expect(Dispensacion.exists?(d.id)).to be(true)
    expect(stock.reload.cantidad).to eq(90)
  end

  it 'BLOQUEA también con una dispensa anulada: es historia del paciente' do
    dispensar.update_column(:estado_envio, 'cancelada')
    expect(described_class.new(stock: stock, usuario: admin).motivo_bloqueo).to match(/ya tiene dispensas/)
  end

  it 'BLOQUEA si el stock va en la segunda línea de una dispensa de varios productos' do
    otro = Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100)
    d = Dispensacion.create!(paciente: paciente, user: admin, fecha_dispensacion: Time.zone.today, medio_pago: 'efectivo',
                             items_attributes: [{ stock_id: otro.id, cantidad: 5 }, { stock_id: stock.id, cantidad: 5 }])
    expect(d.stock_id).to eq(otro.id) # la columna espejo sólo tiene la primera línea
    expect(described_class.new(stock: stock, usuario: admin).motivo_bloqueo).to match(/ya tiene dispensas/)
  end

  it 'sin dispensas se elimina, y motivo_bloqueo es nil' do
    servicio = described_class.new(stock: stock, usuario: admin)
    expect(servicio.motivo_bloqueo).to be_nil
    servicio.eliminar!
    expect(Stock.exists?(stock.id)).to be(false)
  end

  it 'borra también las reservas pendientes sin seña' do
    r = Reserva.create!(club: club, paciente: paciente, stock: stock, user: admin,
                        cantidad: 5, estado: 'pendiente', fecha_entrega_estimada: Time.zone.today + 3, sena_ars: 0)
    described_class.new(stock: stock, usuario: admin).eliminar!
    expect(Reserva.exists?(r.id)).to be(false)
  end

  it 'BLOQUEA si hay una reserva con seña' do
    Reserva.create!(club: club, paciente: paciente, stock: stock, user: admin,
                    cantidad: 5, estado: 'pendiente', fecha_entrega_estimada: Time.zone.today + 3, sena_ars: 1000)
    expect {
      described_class.new(stock: stock, usuario: admin).eliminar!
    }.to raise_error(EliminarStockService::Bloqueado, /seña/)
  end
end
