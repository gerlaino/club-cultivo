require 'rails_helper'

# F4 — el mostrador del salón vende más allá del depósito Salón: producto del bar + insumo
# (cultivo/general). Cada línea descuenta de SU depósito, sin duplicar la mercadería.
# NINGÚN `Stock` se vende acá (ni propio, ni derivados, ni externo): todo lo trazable sale por
# dispensación. Dos puertas de salida para el mismo ítem = descuadre.
RSpec.describe Bar::RegistrarVenta do
  let(:club)   { create(:club, features: { 'bar' => true }) }
  let(:admin)  { create(:user, :admin, club: club) }
  let(:sede)   { create(:sede, club: club, tipo: 'social') }
  let(:bar)    { create(:barra, club: club, sede: sede) }

  let!(:cerveza) { create(:bar_producto, club: club, bar: bar, nombre: 'Cerveza', stock: 20, precio_ars: 2500, costo_ars: 1200) }
  let!(:remera) do
    club.insumos.create!(nombre: 'Remera club', unidad_medida: 'unidad',
                         stock_actual: 10, costo_promedio_ars: 8000)
  end
  let!(:agua)    do
    create(:stock, :externo, club: club, sede: sede, cantidad: 24, unidad: 'un',
                             costo_unitario_ars: 700, precio_sugerido_ars: 1200, descripcion: 'Agua saborizada')
  end
  let(:lote) { create(:lote, club: club) }
  let!(:flor) do
    create(:stock, club: club, sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca',
                   cantidad: 100, costo_unitario_ars: 50, precio_sugerido_ars: 3000, descripcion: 'Kush')
  end

  def vender(lineas, gestion: true, vendedor: admin)
    described_class.new(bar, vendedor, lineas: lineas, medio_pago: 'efectivo',
                                       permite_precio_manual: gestion).call
  end

  describe 'venta de un insumo de otro depósito' do
    it 'descuenta del insumo y deja la línea apuntando al vendible' do
      venta = vender([{ vendible_type: 'Insumo', vendible_id: remera.id, cantidad: 2, precio_unitario_ars: 18_000 }])

      expect(venta.total_ars).to eq(36_000)
      expect(remera.reload.stock_actual).to eq(8)
      expect(cerveza.reload.stock).to eq(20) # no tocó el depósito del salón

      item = venta.items.first
      expect(item.vendible).to eq(remera)
      expect(item.bar_producto).to be_nil
      expect(item.nombre).to eq('Remera club')
    end

    it 'un insumo sin precio manual no se puede vender (no tiene precio propio)' do
      expect { vender([{ vendible_type: 'Insumo', vendible_id: remera.id, cantidad: 1 }]) }
        .to raise_error(ArgumentError, /no tiene precio de venta cargado/)
    end

    it 'el dispensador no puede fijar el precio a mano' do
      disp = create(:user, :dispensador, club: club)
      expect { vender([{ vendible_type: 'Insumo', vendible_id: remera.id, cantidad: 1, precio_unitario_ars: 5 }],
                      gestion: false, vendedor: disp) }
        .to raise_error(ArgumentError, /No podés fijar el precio a mano/)
    end

    it 'no vende más de lo que hay en el depósito de origen' do
      expect { vender([{ vendible_type: 'Insumo', vendible_id: remera.id, cantidad: 99, precio_unitario_ars: 100 }]) }
        .to raise_error(ArgumentError, /Sin stock suficiente/)
      expect(remera.reload.stock_actual).to eq(10)
    end
  end

  # Todo lo que es Stock tiene UNA sola puerta de salida: la dispensación.
  describe 'stock (propio, derivados y externo)' do
    it 'no vende stock externo aunque tenga precio sugerido' do
      expect { vender([{ vendible_type: 'Stock', vendible_id: agua.id, cantidad: 3 }]) }
        .to raise_error(ArgumentError, /dispensación/)
      expect(agua.reload.cantidad).to eq(24)
    end

    it 'no vende flor' do
      expect { vender([{ vendible_type: 'Stock', vendible_id: flor.id, cantidad: 5 }]) }
        .to raise_error(ArgumentError, /dispensación/)
      expect(flor.reload.cantidad).to eq(100)
    end

    it 'no deja descontar un stock ni saltándose la validación de vendible' do
      item = Bar::ItemVendible.new(agua)
      expect(item.vendible?).to be false
      expect { item.descontar!(cantidad: 1, usuario: admin) }.to raise_error(ArgumentError, /dispensación/)
      expect(agua.reload.cantidad).to eq(24)
    end
  end

  describe 'venta mixta (salón + otro depósito en un ticket)' do
    it 'descuenta cada línea de su propio depósito' do
      venta = vender([
        { vendible_type: 'BarProducto', vendible_id: cerveza.id, cantidad: 2 },
        { vendible_type: 'Insumo',      vendible_id: remera.id,  cantidad: 1, precio_unitario_ars: 18_000 },
      ])

      expect(venta.items.count).to eq(2)
      expect(venta.total_ars).to eq(2500 * 2 + 18_000)
      expect(cerveza.reload.stock).to eq(18)
      expect(remera.reload.stock_actual).to eq(9)
    end

    it 'al borrar la venta cada ítem vuelve a su depósito' do
      venta = vender([
        { vendible_type: 'BarProducto', vendible_id: cerveza.id, cantidad: 2 },
        { vendible_type: 'Insumo',      vendible_id: remera.id,  cantidad: 1, precio_unitario_ars: 18_000 },
      ])
      venta.destroy

      expect(cerveza.reload.stock).to eq(20)
      expect(remera.reload.stock_actual).to eq(10)
    end
  end

  describe 'compat con el shape viejo del POS' do
    it 'sigue aceptando bar_producto_id y llena el vendible' do
      venta = vender([{ bar_producto_id: cerveza.id, cantidad: 1 }])
      item  = venta.items.first
      expect(item.vendible).to eq(cerveza)
      expect(item.bar_producto).to eq(cerveza)
      expect(cerveza.reload.stock).to eq(19)
    end
  end

  describe 'venta de evento con provisión reservada' do
    it 'imputa contra lo reservado del insumo sin volver a descontar stock' do
      evento = bar.eventos_bar.create!(club: club, nombre: 'Aniversario', estado: 'en_curso')
      prov = evento.provisiones.create!(club: club, provisionable: remera, cantidad_prevista: 4)
      prov.aplicar_reserva!(cantidad: 4, usuario: admin)
      prov.update!(cantidad_reservada: 4)
      expect(remera.reload.stock_actual).to eq(6) # ya salió al reservar

      described_class.new(bar, admin, lineas: [{ vendible_type: 'Insumo', vendible_id: remera.id,
                                                 cantidad: 3, precio_unitario_ars: 18_000 }],
                                      evento_bar: evento, permite_precio_manual: true).call

      expect(remera.reload.stock_actual).to eq(6)  # no se descuenta de nuevo
      expect(prov.reload.cantidad_consumida).to eq(3)
    end
  end
end
