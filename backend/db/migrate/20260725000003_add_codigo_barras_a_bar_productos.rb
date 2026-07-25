# Código de barras del producto del bar (para el POS: escaneo con lector físico o cámara).
# Único por bar entre los productos vivos (no borrados): un escaneo resuelve a un solo producto.
class AddCodigoBarrasABarProductos < ActiveRecord::Migration[7.2]
  def change
    add_column :bar_productos, :codigo_barras, :string

    add_index :bar_productos, %i[bar_id codigo_barras], unique: true,
              where: 'codigo_barras IS NOT NULL AND deleted_at IS NULL',
              name: 'index_bar_productos_codigo_barras_por_bar'
  end
end
