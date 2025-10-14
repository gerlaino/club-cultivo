class CreateSocioNotas < ActiveRecord::Migration[7.2]
  def change
    create_table :socio_notas do |t|
      t.bigint :club_id, null: false
      t.bigint :socio_id, null: false
      t.text   :contenido, null: false

      # paranoia
      t.datetime :deleted_at, index: true
      # auditoría
      t.bigint :created_by_id, null: false
      t.bigint :deleted_by_id

      t.timestamps
    end

    add_foreign_key :socio_notas, :clubs, column: :club_id
    add_foreign_key :socio_notas, :socios, column: :socio_id
    add_foreign_key :socio_notas, :users,  column: :created_by_id
    add_foreign_key :socio_notas, :users,  column: :deleted_by_id

    add_index :socio_notas, :club_id
    add_index :socio_notas, [:socio_id, :created_at], order: { created_at: :desc }, name: "idx_socio_notas_socio_created_desc"
  end
end

