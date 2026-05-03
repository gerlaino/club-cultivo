class CreateLecturasAmbientalesDiarias < ActiveRecord::Migration[7.2]
  def change
    create_table :lecturas_ambientales_diarias do |t|
      t.bigint :club_id, null: false
      t.references :sala, null: false, foreign_key: true

      t.string  :tipo,       null: false
      t.date    :fecha,      null: false
      t.decimal :valor_min,  null: false, precision: 10, scale: 4
      t.decimal :valor_max,  null: false, precision: 10, scale: 4
      t.decimal :valor_avg,  null: false, precision: 10, scale: 4
      t.decimal :valor_p5,              precision: 10, scale: 4
      t.decimal :valor_p95,             precision: 10, scale: 4
      t.integer :n_lecturas, null: false

      t.timestamps
    end

    # sala_id ya tiene índice por t.references
    add_index :lecturas_ambientales_diarias, [:sala_id, :tipo, :fecha],
              unique: true,
              name: 'idx_lad_unique'
    add_index :lecturas_ambientales_diarias, [:club_id, :fecha],
              name: 'idx_lad_club_fecha'
  end
end
