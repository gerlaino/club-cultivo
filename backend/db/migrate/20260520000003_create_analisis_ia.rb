class CreateAnalisisIa < ActiveRecord::Migration[7.1]
  def change
    create_table :analisis_ia do |t|
      t.references :club, null: false, foreign_key: true
      t.references :lote, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string  :tipo,          null: false
      t.text    :contenido,     null: false
      t.integer :tokens_usados
      t.timestamps
    end
    add_index :analisis_ia, [:lote_id, :created_at]
  end
end
