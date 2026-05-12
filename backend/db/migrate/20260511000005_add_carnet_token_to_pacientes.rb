class AddCarnetTokenToPacientes < ActiveRecord::Migration[7.2]
  def up
    add_column :pacientes, :carnet_token, :string
    add_index  :pacientes, :carnet_token, unique: true

    # Backfill existing records
    execute <<-SQL
      UPDATE pacientes SET carnet_token = gen_random_uuid()::text WHERE carnet_token IS NULL
    SQL

    change_column_null :pacientes, :carnet_token, false
  end

  def down
    remove_column :pacientes, :carnet_token
  end
end
