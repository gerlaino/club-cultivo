class CreateAnalisisLaboratorio < ActiveRecord::Migration[7.0]
  def change
    create_table :analisis_laboratorio do |t|
      t.references :lote,     null: false, foreign_key: true
      t.references :genetica, null: true,  foreign_key: true
      t.bigint     :club_id,  null: false
      t.bigint     :user_id,  null: false
      t.date       :fecha_analisis
      t.string     :laboratorio
      t.decimal    :thc_pct,  precision: 5, scale: 2
      t.decimal    :cbd_pct,  precision: 5, scale: 2
      t.decimal    :cbg_pct,  precision: 5, scale: 2
      t.string     :terpenos_principales
      t.text       :notas
      t.timestamps
    end

    add_index :analisis_laboratorio, :club_id
    add_index :analisis_laboratorio, :lote_id
  end
end
