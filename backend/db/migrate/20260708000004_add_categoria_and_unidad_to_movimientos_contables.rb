class AddCategoriaAndUnidadToMovimientosContables < ActiveRecord::Migration[7.2]
  # La categoría editable entra como categoria_contable_id (FK) conviviendo con
  # la columna legacy `categoria` (string), que se sigue auto-derivando para no
  # romper la lógica de sistema (aporte_socio, dispensacion, costos por lote).
  # unidad_negocio_id habilita el P&L por unidad. Ambas opcionales: nada existente se rompe.
  def change
    add_reference :movimientos_contables, :categoria_contable, null: true,
                  foreign_key: { to_table: :categorias_contables }
    add_reference :movimientos_contables, :unidad_negocio, null: true,
                  foreign_key: { to_table: :unidades_negocio }
  end
end
