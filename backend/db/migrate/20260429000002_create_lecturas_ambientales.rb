class CreateLecturasAmbientales < ActiveRecord::Migration[7.2]
  def change
    create_table :lecturas_ambientales do |t|
      t.bigint  :club_id,        null: false
      t.references :sala,        null: false, foreign_key: true
      t.references :dispositivo, foreign_key: true
      t.references :lote,        foreign_key: true

      t.string  :tipo,     null: false
      t.decimal :valor,    null: false, precision: 10, scale: 4
      t.string  :unidad,   null: false, limit: 20
      t.datetime :medido_at, null: false
      t.string  :fuente,   null: false, default: 'manual'

      t.string :origen_record_type
      t.bigint :origen_record_id

      t.timestamps
    end

    # Nota: sala_id, dispositivo_id, lote_id ya tienen índices por t.references

    # Idempotencia por dispositivo (webhook)
    add_index :lecturas_ambientales, [:dispositivo_id, :tipo, :medido_at],
              unique: true,
              where: 'dispositivo_id IS NOT NULL',
              name: 'idx_la_idempotencia'

    # Queries de timeseries
    add_index :lecturas_ambientales, [:sala_id, :tipo, :medido_at],
              name: 'idx_la_sala_tipo_medido'
    add_index :lecturas_ambientales, [:club_id, :medido_at],
              name: 'idx_la_club_medido'
    add_index :lecturas_ambientales, [:origen_record_type, :origen_record_id],
              where: 'origen_record_id IS NOT NULL',
              name: 'idx_la_origen'
  end
end
