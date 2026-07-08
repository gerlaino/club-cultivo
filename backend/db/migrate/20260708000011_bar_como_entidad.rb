class BarComoEntidad < ActiveRecord::Migration[7.2]
  # El bar deja de ser "global por unidad de negocio" y pasa a ser una entidad ligada a una
  # sede social/mixta. Productos y ventas cuelgan del bar. Se agrega deleted_by_id para que
  # todo sea recuperable desde la papelera (patrón Restorable).
  def change
    create_table :bares do |t|
      t.references :club,       null: false, foreign_key: true
      t.references :sede,       null: false, foreign_key: true
      t.references :deleted_by, null: true,  foreign_key: { to_table: :users }
      t.string  :nombre, null: false
      t.boolean :activo, null: false, default: true
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :bares, :deleted_at
    add_index :bares, [:club_id, :sede_id]

    # Productos y ventas ahora pertenecen a un bar concreto (nullable: las filas viejas —vacías—
    # no lo tienen; las nuevas sí). FK explícita para evitar el bug de pluralización.
    add_reference :bar_productos, :bar, null: true, foreign_key: { to_table: :bares }
    add_reference :bar_ventas,    :bar, null: true, foreign_key: { to_table: :bares }

    # deleted_by para la papelera (las tablas bar se crearon después de la migración global de soft-delete).
    add_reference :bar_productos, :deleted_by, null: true, foreign_key: { to_table: :users }
    add_reference :bar_ventas,    :deleted_by, null: true, foreign_key: { to_table: :users }

    # Las líneas de venta pasan a ser soft-deletable para poder restaurar una venta completa
    # (vuelven con su venta, como las líneas de dispensación).
    add_column :bar_venta_items, :deleted_at, :datetime
    add_index  :bar_venta_items, :deleted_at
  end
end
