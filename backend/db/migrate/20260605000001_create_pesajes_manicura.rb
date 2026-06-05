class CreatePesajesManicura < ActiveRecord::Migration[7.0]
  def change
    create_table :pesajes_manicura do |t|
      t.references :lote,          null: false, foreign_key: true
      t.references :manicurador,   null: false, foreign_key: { to_table: :users }
      t.references :club,          null: false, foreign_key: true
      t.references :stock,         null: true,  foreign_key: true
      t.references :confirmado_por, null: true, foreign_key: { to_table: :users }

      t.date    :fecha_pesaje,      null: false
      t.string  :estado,            null: false, default: 'borrador'
      t.decimal :peso_total_g,      precision: 10, scale: 2
      t.decimal :peso_confirmado_g, precision: 10, scale: 2
      t.integer :plantas_count
      t.text    :notas
      t.datetime :enviado_at
      t.datetime :confirmado_at

      t.timestamps
    end

    add_index :pesajes_manicura, [:lote_id, :estado]
    add_index :pesajes_manicura, [:club_id, :estado]
    add_index :pesajes_manicura, :fecha_pesaje
  end

  def down
    drop_table :pesajes_manicura
  end
end
