class CreatePlants < ActiveRecord::Migration[7.2]
  def change
    create_table :plants do |t|
      t.references :lote, null: false, foreign_key: true
      t.string :codigo_qr
      t.string :nombre
      t.references :genetica, null: false, foreign_key: true
      t.string :state
      t.date :fecha_germinacion
      t.date :fecha_vegetativo
      t.date :fecha_floracion
      t.date :fecha_cosecha
      t.decimal :peso_seco
      t.text :notas

      t.timestamps
    end
    add_index :plants, :codigo_qr, unique: true
  end
end
