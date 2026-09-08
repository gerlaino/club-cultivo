# LA COMPRA EN CUOTAS SE OLVIDABA DE QUÉ CATEGORÍA ERA.
#
# `movimientos_contables` guarda la categoría REAL del catálogo (`categoria_contable_id`) además
# de la clave legacy; `compras_cuotas` sólo guardaba la clave. Como las categorías propias del
# club no tienen clave legacy —caen todas en `otro`—, cada cuota entraba al libro diciendo "Otro"
# en vez de "Bienes de Uso", que es lo que la persona había elegido en pantalla.
#
# No alcanzaba con pasarla al vuelo: editar una compra REGENERA las cuotas
# (`actualizar_y_regenerar!`), así que sin guardarla se perdía en la primera edición.
class AddCategoriaContableAComprasCuotas < ActiveRecord::Migration[7.2]
  def change
    add_reference :compras_cuotas, :categoria_contable, foreign_key: { to_table: :categorias_contables }
  end
end
