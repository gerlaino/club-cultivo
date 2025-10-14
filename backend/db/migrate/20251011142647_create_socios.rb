class CreateSocios < ActiveRecord::Migration[7.2]
  def change
    create_table :socios do |t|
      t.bigint :club_id, null: false
      t.string :nombre, null: false
      t.string :apellido, null: false
      t.string :dni, null: false
      t.string :dni_normalizado, null: false
      t.date   :fecha_nacimiento, null: false
      t.boolean :es_paciente, null: false, default: true

      # paranoia
      t.datetime :deleted_at, index: true
      # auditoría
      t.bigint :created_by_id, null: false
      t.bigint :updated_by_id
      t.bigint :deleted_by_id

      t.timestamps
    end

    add_foreign_key :socios, :clubs, column: :club_id
    add_foreign_key :socios, :users, column: :created_by_id
    add_foreign_key :socios, :users, column: :updated_by_id
    add_foreign_key :socios, :users, column: :deleted_by_id

    add_index :socios, :club_id
    add_index :socios, :dni_normalizado, unique: true
    add_index :socios, "lower(nombre)"
    add_index :socios, "lower(apellido)"
    add_index :socios, :created_at
  end
end


