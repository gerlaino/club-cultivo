class AddFieldsToSalas < ActiveRecord::Migration[7.1]
  def change
    add_column :salas, :kind, :string, default: "indoor", null: false unless column_exists?(:salas, :kind)
    add_reference :salas, :created_by, foreign_key: { to_table: :users }, index: true unless column_exists?(:salas, :created_by_id)
    add_column :salas, :camera_stream_url, :string unless column_exists?(:salas, :camera_stream_url)
    add_column :salas, :camera_snapshot_url, :string unless column_exists?(:salas, :camera_snapshot_url)
  end
end
