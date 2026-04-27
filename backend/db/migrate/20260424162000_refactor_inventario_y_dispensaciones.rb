class RefactorInventarioYDispensaciones < ActiveRecord::Migration[7.1]
  def change
    # sede_inventarios: genetica como identificador principal, precio por unidad
    add_reference :sede_inventarios, :genetica, null: true, foreign_key: true
    add_column    :sede_inventarios, :precio_por_unidad, :decimal, precision: 10, scale: 2

    change_column_null :sede_inventarios, :producto, true

    remove_index :sede_inventarios,
                 name: "index_sede_inventarios_on_sede_id_and_producto",
                 if_exists: true

    add_index :sede_inventarios, [:sede_id, :genetica_id],
              unique: true,
              where: "genetica_id IS NOT NULL",
              name: "index_sede_inv_sede_genetica_unique"

    # dispensaciones: link directo a stock + descuento
    add_reference :dispensaciones, :sede_inventario, null: true, foreign_key: true
    add_column    :dispensaciones, :porcentaje_descuento, :decimal, precision: 5, scale: 2
  end
end
