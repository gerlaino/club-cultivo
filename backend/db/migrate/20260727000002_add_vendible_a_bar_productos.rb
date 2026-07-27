# Producto del bar: `vendible` distingue lo que está en el catálogo del POS (default) de lo que se
# guarda en el depósito del salón pero NO se vende (insumos de barra, deco, etc.). Un "no vender"
# aparece en Stock del salón (deshabilitado, solo para gestión) y nunca en Vender.
class AddVendibleABarProductos < ActiveRecord::Migration[7.2]
  def change
    add_column :bar_productos, :vendible, :boolean, default: true, null: false
  end
end
