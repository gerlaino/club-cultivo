require 'rails_helper'

RSpec.describe Bar::RegistrarVenta, type: :service do
  let(:club)     { create(:club) }
  let(:vendedor) { create(:user, :dispensador, club: club) }

  before { ActsAsTenant.current_tenant = club }
  after  { ActsAsTenant.current_tenant = nil }

  def producto(attrs = {})
    club.bar_productos.create!({ nombre: 'Café', categoria: 'bebida', precio_ars: 900, stock: 40 }.merge(attrs))
  end

  it 'registra la venta, descuenta stock y calcula el total' do
    cafe = producto
    cerv = producto(nombre: 'Cerveza', precio_ars: 2400, stock: 18)
    venta = described_class.new(club, vendedor,
      lineas: [{ bar_producto_id: cafe.id, cantidad: 2 }, { bar_producto_id: cerv.id, cantidad: 1 }],
      medio_pago: 'efectivo').call

    expect(venta.total_ars).to eq(2 * 900 + 2400)
    expect(cafe.reload.stock).to eq(38)
    expect(cerv.reload.stock).to eq(17)
    expect(venta.items.count).to eq(2)
  end

  it 'genera un ingreso contable en la unidad Bar' do
    cafe = producto
    expect {
      described_class.new(club, vendedor, lineas: [{ bar_producto_id: cafe.id, cantidad: 1 }]).call
    }.to change { club.movimientos_contables.where(tipo: 'ingreso').count }.by(1)

    mov = club.movimientos_contables.where(tipo: 'ingreso').last
    expect(mov.unidad_negocio.tipo).to eq('bar')
    expect(mov.monto_ars).to eq(900)
    expect(mov.pagado).to be(true)
  end

  it 'la venta cuenta como ingreso real del libro' do
    cafe = producto
    described_class.new(club, vendedor, lineas: [{ bar_producto_id: cafe.id, cantidad: 3 }]).call
    expect(MovimientoContable.ingresos.sum(:monto_ars)).to eq(2700)
  end

  it 'rechaza la venta si no hay stock suficiente y no descuenta nada' do
    cafe = producto(stock: 1)
    expect {
      described_class.new(club, vendedor, lineas: [{ bar_producto_id: cafe.id, cantidad: 5 }]).call
    }.to raise_error(ArgumentError, /stock/i)
    expect(cafe.reload.stock).to eq(1)         # rollback
    expect(club.bar_ventas.count).to eq(0)     # rollback
  end

  it 'rechaza una venta sin líneas' do
    expect { described_class.new(club, vendedor, lineas: []).call }.to raise_error(ArgumentError, /productos/)
  end
end
