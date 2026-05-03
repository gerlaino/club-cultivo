class CreateReglasAmbientales < ActiveRecord::Migration[7.2]
  def change
    create_table :reglas_ambientales do |t|
      t.bigint :club_id, null: false
      t.references :sala, foreign_key: true

      t.string  :nombre,           null: false
      t.text    :descripcion
      t.string  :tipo_lectura,     null: false
      t.string  :condicion,        null: false
      t.decimal :umbral_a,         null: false, precision: 10, scale: 4
      t.decimal :umbral_b,                      precision: 10, scale: 4
      t.integer :duracion_minutos, null: false, default: 5
      t.string  :accion,           null: false, default: 'notificar'
      t.string  :prioridad,        null: false, default: 'media'
      t.boolean :activa,           null: false, default: true
      t.text    :webhook_url

      t.timestamps
    end

    # sala_id ya tiene índice por t.references
    add_index :reglas_ambientales, [:club_id, :activa],
              name: 'idx_reglas_club_activa'
    add_index :reglas_ambientales, :sala_id,
              where: 'sala_id IS NOT NULL',
              name: 'idx_reglas_sala',
              if_not_exists: true
  end
end
