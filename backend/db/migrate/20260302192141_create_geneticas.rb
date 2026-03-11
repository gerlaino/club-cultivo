class CreateGeneticas < ActiveRecord::Migration[7.2]
  def change
    create_table :geneticas do |t|
      t.references :club, null: false, foreign_key: true, index: true
      t.string :nombre, null: false
      t.text :descripcion
      t.decimal :thc, precision: 5, scale: 2
      t.decimal :cbd, precision: 5, scale: 2
      t.boolean :disponible, default: true, null: false
      t.boolean :activa, default: true, null: false
      t.string :tipo

      t.timestamps
    end

    # Solo agregar los índices que NO existen
    add_index :geneticas, :activa
    add_index :geneticas, [:club_id, :activa]
  end
end
