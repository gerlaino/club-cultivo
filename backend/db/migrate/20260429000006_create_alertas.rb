class CreateAlertas < ActiveRecord::Migration[7.2]
  def change
    create_table :alertas do |t|
      t.bigint     :club_id,  null: false
      t.references :regla,    null: false, foreign_key: { to_table: :reglas_ambientales }
      t.references :sala,     null: false, foreign_key: true
      t.references :lectura,  foreign_key: { to_table: :lecturas_ambientales }

      t.string  :estado,  null: false, default: 'activa'
      t.text    :mensaje, null: false

      t.datetime :reconocida_at
      t.references :reconocida_por, foreign_key: { to_table: :users }
      t.datetime :resuelta_at
      t.references :resuelta_por,  foreign_key: { to_table: :users }

      t.timestamps
    end

    # regla_id, sala_id, lectura_id, reconocida_por_id, resuelta_por_id ya tienen índices por t.references
    add_index :alertas, [:club_id, :estado], name: 'idx_alertas_club_estado'
    add_index :alertas, [:sala_id,  :estado], name: 'idx_alertas_sala_estado'
  end
end
