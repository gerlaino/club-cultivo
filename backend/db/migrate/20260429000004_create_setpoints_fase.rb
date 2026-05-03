class CreateSetpointsFase < ActiveRecord::Migration[7.2]
  def change
    create_table :setpoints_fase do |t|
      t.bigint :club_id, null: false
      t.references :genetica, foreign_key: { to_table: :geneticas }

      t.string  :fase,         null: false
      t.string  :tipo_lectura, null: false
      t.decimal :valor_min,    precision: 10, scale: 4
      t.decimal :valor_max,    precision: 10, scale: 4
      t.decimal :valor_ideal,  precision: 10, scale: 4
      t.string  :unidad,       null: false, limit: 20

      t.timestamps
    end

    add_index :setpoints_fase, [:club_id, :fase],
              name: 'idx_setpoints_club_fase'

    # UNIQUE parciales para manejar NULL correctamente en PostgreSQL
    add_index :setpoints_fase, [:club_id, :fase, :tipo_lectura],
              unique: true,
              where: 'genetica_id IS NULL',
              name: 'idx_setpoints_default'
    add_index :setpoints_fase, [:club_id, :genetica_id, :fase, :tipo_lectura],
              unique: true,
              where: 'genetica_id IS NOT NULL',
              name: 'idx_setpoints_genetica'
  end
end
