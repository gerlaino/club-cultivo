class CreateDispensacionItems < ActiveRecord::Migration[7.2]
  # Líneas de una dispensación: cada una es un stock + cantidad (precio/costo/trazabilidad propios).
  # Permite que una dispensación abarque varios stocks. En la transición, stock_id/cantidad de
  # `dispensaciones` siguen existiendo (mirror de la primera línea) hasta la fase de limpieza.
  def up
    create_table :dispensacion_items do |t|
      t.references :dispensacion, null: false, foreign_key: { to_table: :dispensaciones }
      t.references :stock, null: true, foreign_key: true            # nullify si se borra el stock
      t.decimal :cantidad, precision: 10, scale: 3, null: false, default: 0
      t.decimal :precio_unitario_ars, precision: 10, scale: 2
      t.decimal :costo_unitario_ars,  precision: 10, scale: 2
      t.string  :lote_codigo                                        # snapshot de trazabilidad
      t.string  :genetica_nombre
      t.datetime :deleted_at
      t.bigint   :deleted_by_id
      t.timestamps
    end
    add_index :dispensacion_items, :deleted_at
    add_foreign_key :dispensacion_items, :users, column: :deleted_by_id

    # Backfill: una línea por cada dispensación existente, espejando su deleted_at.
    execute <<~SQL
      INSERT INTO dispensacion_items
        (dispensacion_id, stock_id, cantidad, precio_unitario_ars, lote_codigo, genetica_nombre, deleted_at, created_at, updated_at)
      SELECT id, stock_id, cantidad, precio_unitario_ars, lote_codigo, genetica_nombre, deleted_at, NOW(), NOW()
      FROM dispensaciones
    SQL
  end

  def down
    drop_table :dispensacion_items
  end
end
