class RefactorDispensacionCampos < ActiveRecord::Migration[7.2]
  def up
    add_column :dispensaciones, :cantidad,            :decimal, precision: 10, scale: 3, null: false, default: 0
    add_column :dispensaciones, :precio_unitario_ars,  :decimal, precision: 10, scale: 2

    execute "UPDATE dispensaciones SET cantidad = cantidad_gramos WHERE cantidad_gramos IS NOT NULL"

    remove_column :dispensaciones, :lote_id
    remove_column :dispensaciones, :cantidad_gramos
    remove_column :dispensaciones, :tipo_producto
    remove_column :dispensaciones, :costo_por_gramo
    remove_column :dispensaciones, :costo_total_calculado
    remove_column :dispensaciones, :porcentaje_descuento
  end

  def down
    add_column :dispensaciones, :lote_id,               :bigint
    add_column :dispensaciones, :cantidad_gramos,        :decimal, precision: 8,  scale: 2
    add_column :dispensaciones, :tipo_producto,          :string
    add_column :dispensaciones, :costo_por_gramo,        :decimal, precision: 10, scale: 2
    add_column :dispensaciones, :costo_total_calculado,  :decimal, precision: 10, scale: 2
    add_column :dispensaciones, :porcentaje_descuento,   :decimal, precision: 5,  scale: 2

    execute "UPDATE dispensaciones SET cantidad_gramos = cantidad"
    remove_column :dispensaciones, :cantidad
    remove_column :dispensaciones, :precio_unitario_ars
  end
end
