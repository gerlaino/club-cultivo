class CreateNoticias < ActiveRecord::Migration[7.2]
  def change
    create_table :noticias do |t|
      t.references :club, null: false, foreign_key: true
      t.string :titulo, null: false
      t.text :contenido, null: false
      t.string :cover_url
      t.boolean :publicada, default: false, null: false
      t.datetime :publicada_at

      t.timestamps
    end

    # Solo índices que NO existen
    add_index :noticias, :publicada
    add_index :noticias, [:club_id, :publicada, :publicada_at]
  end
end
