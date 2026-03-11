class CreateEventos < ActiveRecord::Migration[7.2]
  def change
    create_table :eventos do |t|
      t.references :club, null: false, foreign_key: true
      t.string :titulo, null: false
      t.text :descripcion
      t.datetime :fecha_inicio, null: false
      t.datetime :fecha_fin
      t.string :lugar
      t.boolean :activo, default: true, null: false

      t.timestamps
    end

    # Solo índices que NO existen
    add_index :eventos, :activo
    add_index :eventos, [:club_id, :activo, :fecha_inicio]
  end
end
