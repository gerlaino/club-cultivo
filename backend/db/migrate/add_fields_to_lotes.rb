# db/migrate/202510080002_add_fields_to_lotes.rb
class AddFieldsToLotes < ActiveRecord::Migration[7.1]
  def change
    add_column :lotes, :grow_type, :string, default: "sustrato", null: false
    add_column :lotes, :light_type, :string
  end
end
