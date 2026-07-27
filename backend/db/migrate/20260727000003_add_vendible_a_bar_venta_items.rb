# El mostrador del salón deja de vender SOLO productos del bar: una línea de venta ahora puede
# apuntar a cualquier mercadería vendible — BarProducto (depósito Salón), Insumo (cultivo/general)
# o Stock externo (merch/bebida). Cada una descuenta de SU depósito.
#
# `bar_producto_id` se conserva (no se borra) por compatibilidad con el código y los tickets
# históricos; para las líneas de productos del bar ambas referencias apuntan a lo mismo.
class AddVendibleABarVentaItems < ActiveRecord::Migration[7.2]
  def up
    add_reference :bar_venta_items, :vendible, polymorphic: true, null: true, index: true

    # Backfill: toda línea existente es de un producto del bar.
    execute <<~SQL
      UPDATE bar_venta_items
         SET vendible_type = 'BarProducto', vendible_id = bar_producto_id
       WHERE bar_producto_id IS NOT NULL
    SQL
  end

  def down
    remove_reference :bar_venta_items, :vendible, polymorphic: true
  end
end
