class AddFieldsToSalas < ActiveRecord::Migration[7.2]
  def change
    add_column :salas, :kind, :string
    add_reference :salas, :created_by, foreign_key: { to_table: :users }, null: true
    add_column :salas, :camera_stream_url, :string
    add_column :salas, :camera_snapshot_url, :string

    reversible do |dir|
      dir.up do
        # Relleno: asigno el primer usuario existente como creador de todas las salas
        execute <<~SQL
          UPDATE salas
          SET created_by_id = (
            SELECT id FROM users ORDER BY id ASC LIMIT 1
          )
          WHERE created_by_id IS NULL;
        SQL

        change_column_null :salas, :created_by_id, false
      end
    end
  end
end

