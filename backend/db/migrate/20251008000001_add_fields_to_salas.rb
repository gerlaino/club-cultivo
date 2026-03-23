# db/migrate/202510080001_add_fields_to_salas.rb
class AddFieldsToSalas < ActiveRecord::Migration[7.1]
  def change
    add_column :salas, :kind, :string, default: "indoor", null: false
    add_reference :salas, :created_by, foreign_key: { to_table: :users }, index: true
    add_column :salas, :camera_stream_url, :string
    add_column :salas, :camera_snapshot_url, :string
  end
end
