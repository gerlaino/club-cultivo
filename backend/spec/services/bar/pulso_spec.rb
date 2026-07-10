require 'rails_helper'

RSpec.describe Bar::Pulso, type: :service do
  let(:club)  { create(:club) }
  let(:user)  { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'social') }
  let(:bar)   { create(:barra, club: club, sede: sede) }

  before { ActsAsTenant.current_tenant = club }
  after  { ActsAsTenant.current_tenant = nil }

  # Helper: registra una venta de `cant` unidades de `producto` a un medio de pago dado.
  def vender(producto, cant, medio: 'efectivo', total: nil)
    total ||= producto.precio_ars * cant
    venta = create(:bar_venta, club: club, bar: bar, user: user, total_ars: total, medio_pago: medio)
    create(:bar_venta_item, club: club, bar_venta: venta, bar_producto: producto,
                            nombre: producto.nombre, cantidad: cant,
                            precio_unitario_ars: producto.precio_ars, subtotal_ars: producto.precio_ars * cant)
    venta
  end

  describe '#call' do
    it 'arma el top de hoy ordenado por unidades con el margen del producto' do
      cafe    = create(:bar_producto, club: club, bar: bar, nombre: 'Café', precio_ars: 1000, costo_ars: 300)
      cerveza = create(:bar_producto, club: club, bar: bar, nombre: 'Cerveza', precio_ars: 2000, costo_ars: 1000)
      vender(cafe, 5)
      vender(cerveza, 2)

      top = described_class.new(bar: bar).call[:top_productos]
      expect(top.first[:nombre]).to eq('Café')
      expect(top.first[:cantidad]).to eq(5.0)
      expect(top.first[:margen_pct]).to eq(70.0) # (1000-300)/1000
    end

    it 'reparte la caja de hoy en efectivo y digital' do
      prod = create(:bar_producto, club: club, bar: bar, precio_ars: 1000)
      vender(prod, 1, medio: 'efectivo', total: 1000)
      vender(prod, 1, medio: 'transferencia', total: 1500)

      hoy = described_class.new(bar: bar).call[:hoy]
      expect(hoy[:total]).to eq(2500.0)
      expect(hoy[:efectivo]).to eq(1000.0)
      expect(hoy[:digital]).to eq(1500.0)
      expect(hoy[:tickets]).to eq(2)
    end

    it 'calcula el margen bruto del día sobre las líneas con costo conocido' do
      prod = create(:bar_producto, club: club, bar: bar, precio_ars: 1000, costo_ars: 400)
      vender(prod, 2, total: 2000) # ingreso 2000, costo 800 → margen 60%
      expect(described_class.new(bar: bar).call[:hoy][:margen_bruto_pct]).to eq(60.0)
    end

    it 'incluye una lectura de estrella con el producto más vendido' do
      cafe = create(:bar_producto, club: club, bar: bar, nombre: 'Café', precio_ars: 1000, costo_ars: 300)
      vender(cafe, 8)
      lecturas = described_class.new(bar: bar).call[:lecturas]
      expect(lecturas).to include(a_hash_including(tono: 'good', texto: a_string_matching(/Café es tu estrella/)))
    end

    it 'lista los productos bajo el mínimo para reponer con su porcentaje' do
      create(:bar_producto, club: club, bar: bar, nombre: 'Leche', stock: 1, stock_minimo: 10)
      reponer = described_class.new(bar: bar).call[:reponer]
      expect(reponer.map { |r| r[:nombre] }).to include('Leche')
      expect(reponer.first[:pct]).to eq(10) # 1/10
    end

    it 'expone el resultado del mes con margen' do
      # una venta genera el ingreso contable vía Bar::RegistrarVenta; acá validamos la forma
      rm = described_class.new(bar: bar).call[:resultado_mes]
      expect(rm).to include(:ingresos, :egresos, :resultado, :margen_pct, :delta_pct)
    end
  end
end
