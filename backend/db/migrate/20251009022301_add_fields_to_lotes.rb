class AddFieldsToLotes < ActiveRecord::Migration[7.2]
  def change
    add_column :lotes, :grow_type, :string
    add_column :lotes, :light_type, :string
  end
end
