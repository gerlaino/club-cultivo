class CreateInsumoConsumos < ActiveRecord::Migration[7.2]
  # Un consumo de insumo: descuenta stock e imputa el costo (al promedio del momento)
  # al lote y/o sala donde se usó. Es la fuente del costo real de insumos por lote.
  def change
    create_table :insumo_consumos do |t|
      t.references :club,       null: false, foreign_key: true
      t.references :insumo,     null: false, foreign_key: true
      t.references :lote,       null: true,  foreign_key: true
      t.references :sala,       null: true,  foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.decimal :cantidad,           precision: 14, scale: 3, null: false
      t.decimal :costo_imputado_ars, precision: 14, scale: 2, null: false
      t.date    :fecha, null: false
      t.text    :notas
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :insumo_consumos, :deleted_at
    add_index :insumo_consumos, [:club_id, :lote_id]
  end
end
