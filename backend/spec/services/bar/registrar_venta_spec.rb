require 'rails_helper'

RSpec.describe Bar::RegistrarVenta, type: :service do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:vendedor) { create(:user, :dispensador, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin, tipo: 'mixta') }
  let(:bar)      { club.bares.create!(sede: sede, nombre: 'La Terraza') }

  before { ActsAsTenant.current_tenant = club }
  after  { ActsAsTenant.current_tenant = nil }

  def producto(attrs = {})
    bar.bar_productos.create!({ club: club, nombre: 'Café', categoria: 'bebida', precio_ars: 900, stock: 40 }.merge(attrs))
  end

  it 'no registra la venta si el evento atribuido está finalizado/cancelado' do
    cafe = producto
    evento = bar.eventos_bar.create!(club: club, nombre: 'Cerrado', fecha: Date.current, estado: 'finalizado')
    expect {
      described_class.new(bar, vendedor, lineas: [{ bar_producto_id: cafe.id, cantidad: 1 }], evento_bar: evento).call
    }.to raise_error(ArgumentError, /finalizado/)
    expect(cafe.reload.stock).to eq(40) # no se tocó
  end

  it 'registra la venta, descuenta stock y calcula el total' do
    cafe = producto
    cerv = producto(nombre: 'Cerveza', precio_ars: 2400, stock: 18)
    venta = described_class.new(bar, vendedor,
      lineas: [{ bar_producto_id: cafe.id, cantidad: 2 }, { bar_producto_id: cerv.id, cantidad: 1 }]).call

    expect(venta.total_ars).to eq(2 * 900 + 2400)
    expect(cafe.reload.stock).to eq(38)
    expect(venta.bar_id).to eq(bar.id)
  end

  it 'genera un ingreso contable en la unidad Bar y la sede del bar' do
    cafe = producto
    described_class.new(bar, vendedor, lineas: [{ bar_producto_id: cafe.id, cantidad: 1 }]).call
    mov = club.movimientos_contables.where(tipo: 'ingreso').last
    expect(mov.unidad_negocio.tipo).to eq('bar')
    expect(mov.sede_id).to eq(sede.id)
    expect(mov.monto_ars).to eq(900)
  end

  it 'rechaza la venta si no hay stock y no descuenta nada' do
    cafe = producto(stock: 1)
    expect { described_class.new(bar, vendedor, lineas: [{ bar_producto_id: cafe.id, cantidad: 5 }]).call }
      .to raise_error(ArgumentError, /stock/i)
    expect(cafe.reload.stock).to eq(1)
    expect(bar.bar_ventas.count).to eq(0)
  end

  describe 'borrar y restaurar una venta' do
    it 'al borrar devuelve el stock y saca el ingreso del libro' do
      cafe = producto(stock: 10)
      venta = described_class.new(bar, vendedor, lineas: [{ bar_producto_id: cafe.id, cantidad: 3 }]).call
      expect(cafe.reload.stock).to eq(7)

      venta.destroy
      expect(cafe.reload.stock).to eq(10) # devuelto
      expect(MovimientoContable.ingresos.sum(:monto_ars)).to eq(0)
    end

    it 'al restaurar vuelve a descontar el stock y re-crea el ingreso' do
      cafe = producto(stock: 10)
      venta = described_class.new(bar, vendedor, lineas: [{ bar_producto_id: cafe.id, cantidad: 3 }]).call
      venta.destroy

      res = Restore::Restorers::BarVenta.call(BarVenta.with_deleted.find(venta.id), usuario: admin)
      expect(res.ok?).to be(true)
      expect(cafe.reload.stock).to eq(7)
      expect(MovimientoContable.ingresos.sum(:monto_ars)).to eq(2700)
    end

    it 'bloquea la restauración si no hay stock suficiente ahora' do
      cafe = producto(stock: 3)
      venta = described_class.new(bar, vendedor, lineas: [{ bar_producto_id: cafe.id, cantidad: 3 }]).call
      venta.destroy
      cafe.reload.update!(stock: 1) # alguien consumió stock mientras tanto

      res = Restore::Restorers::BarVenta.check(BarVenta.with_deleted.find(venta.id))
      expect(res.ok?).to be(false)
      expect(res.conflicts.first.codigo).to eq('stock_insuficiente')
    end
  end
end

RSpec.describe Bar, type: :model do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  before { ActsAsTenant.current_tenant = club }
  after  { ActsAsTenant.current_tenant = nil }

  it 'no permite un bar en una sede de producción' do
    prod = create(:sede, club: club, created_by: admin, tipo: 'produccion')
    bar = club.bares.build(sede: prod, nombre: 'X')
    expect(bar.valid?).to be(false)
    expect(bar.errors[:sede]).to be_present
  end

  it 'no permite dos bares en la misma sede' do
    sede = create(:sede, club: club, created_by: admin, tipo: 'social')
    club.bares.create!(sede: sede, nombre: 'Uno')
    dos = club.bares.build(sede: sede, nombre: 'Dos')
    expect(dos.valid?).to be(false)
  end
end
