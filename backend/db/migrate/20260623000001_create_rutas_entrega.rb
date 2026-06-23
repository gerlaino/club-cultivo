class CreateRutasEntrega < ActiveRecord::Migration[7.2]
  def change
    create_table :rutas_entrega do |t|
      t.references :club,     null: false, foreign_key: true
      t.references :delivery, null: false, foreign_key: { to_table: :users }
      t.date    :fecha,     null: false
      t.boolean :bloqueada, null: false, default: false
      t.timestamps
    end
    # Una ruta por repartidor y día.
    add_index :rutas_entrega, [:delivery_id, :fecha], unique: true

    add_reference :dispensaciones, :ruta_entrega, null: true,
                  foreign_key: { to_table: :rutas_entrega }
    add_column    :dispensaciones, :orden_entrega, :integer
  end
end
