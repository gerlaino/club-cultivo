class AddFieldsToLotes < ActiveRecord::Migration[7.1]
  def change
    add_column :lotes, :grow_type, :string, default: "sustrato", null: false unless column_exists?(:lotes, :grow_type)
    add_column :lotes, :light_type, :string unless column_exists?(:lotes, :light_type)
  end
end
