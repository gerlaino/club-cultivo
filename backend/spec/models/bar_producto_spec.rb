require 'rails_helper'

RSpec.describe BarProducto, type: :model do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'social') }
  let(:bar)   { create(:barra, club: club, sede: sede) }

  before { ActsAsTenant.current_tenant = club }
  after  { ActsAsTenant.current_tenant = nil }

  def producto(attrs = {})
    create(:bar_producto, { club: club, bar: bar, precio_ars: 1000, costo_ars: 0, stock: 0 }.merge(attrs))
  end

  describe 'asiento contable de la compra' do
    it 'genera el egreso categorizado como "bar" (no "otro") y con la sede del bar' do
      p = producto
      p.registrar_compra!(cantidad: 10, costo_total_ars: 4000, created_by: admin)
      egr = club.movimientos_contables.egresos.order(:created_at).last
      expect(egr.categoria).to eq('bar')
      expect(egr.sede_id).to eq(bar.sede_id)
      expect(egr.unidad_negocio_id).to eq(bar.unidad_negocio_bar.id)
    end
  end

  describe 'código de barras' do
    it 'no permite el mismo código en dos productos del mismo bar' do
      producto(nombre: 'Coca', codigo_barras: '7790895000997')
      dup = build(:bar_producto, club: club, bar: bar, precio_ars: 500, codigo_barras: '7790895000997')
      expect(dup).not_to be_valid
      expect(dup.errors[:codigo_barras]).to be_present
    end

    it 'permite código en blanco en varios productos (es opcional)' do
      producto(nombre: 'Casero 1', codigo_barras: nil)
      expect { producto(nombre: 'Casero 2', codigo_barras: nil) }.not_to raise_error
    end

    it 'el mismo código puede existir en otro bar' do
      otra_sede = create(:sede, club: club, tipo: 'social')
      otro_bar  = create(:barra, club: club, sede: otra_sede, nombre: 'Barra 2')
      producto(nombre: 'Coca', codigo_barras: '123')
      gemelo = build(:bar_producto, club: club, bar: otro_bar, precio_ars: 500, codigo_barras: '123')
      expect(gemelo).to be_valid
    end
  end

  describe '#registrar_compra!' do
    it 'suma stock, fija el costo promedio y deja el movimiento' do
      p = producto
      p.registrar_compra!(cantidad: 10, costo_total_ars: 4000, created_by: admin, generar_egreso: false)
      expect(p.stock).to eq(10)
      expect(p.costo_ars).to eq(400) # 4000/10
      expect(p.bar_stock_movimientos.where(tipo: 'compra').count).to eq(1)
    end

    it 'recalcula el promedio ponderado en una segunda compra a otro precio' do
      p = producto
      p.registrar_compra!(cantidad: 10, costo_total_ars: 4000, created_by: admin, generar_egreso: false) # $400
      p.registrar_compra!(cantidad: 10, costo_total_ars: 6000, created_by: admin, generar_egreso: false) # $600
      expect(p.stock).to eq(20)
      expect(p.costo_ars).to eq(500) # (10*400 + 10*600)/20
    end

    it 'genera el egreso contable de la compra' do
      p = producto
      expect { p.registrar_compra!(cantidad: 5, costo_total_ars: 2000, created_by: admin) }
        .to change { club.movimientos_contables.egresos.count }.by(1)
    end
  end

  describe '#registrar_salida!' do
    it 'descuenta stock y deja el movimiento de venta' do
      p = producto(stock: 20, costo_ars: 400)
      p.registrar_salida!(cantidad: 3, tipo: 'venta', created_by: admin)
      expect(p.reload.stock).to eq(17)
      expect(p.bar_stock_movimientos.where(tipo: 'venta').count).to eq(1)
    end

    it 'lanza si no hay stock suficiente' do
      p = producto(stock: 2)
      expect { p.registrar_salida!(cantidad: 5, tipo: 'venta', created_by: admin) }
        .to raise_error(ArgumentError, /suficiente/)
    end

    it 'avisa reposición al llegar al mínimo' do
      p = producto(stock: 10, stock_minimo: 5)
      expect { p.registrar_salida!(cantidad: 6, tipo: 'venta', created_by: admin) } # queda 4 <= 5
        .to change { club.alertas_internas.where(tipo: 'stock_bajo').count }.by(1)
    end
  end

  describe '#ajustar_stock!' do
    it 'fija el stock y registra la merma cuando baja' do
      p = producto(stock: 10)
      p.ajustar_stock!(cantidad_nueva: 7, created_by: admin, motivo: 'roto')
      expect(p.reload.stock).to eq(7)
      expect(p.bar_stock_movimientos.where(tipo: 'merma').last.cantidad).to eq(3)
    end
  end
end
