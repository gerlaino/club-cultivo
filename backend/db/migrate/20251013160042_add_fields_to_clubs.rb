class AddFieldsToClubs < ActiveRecord::Migration[7.2]
  def change
    add_column :clubs, :legal_name, :string
    add_column :clubs, :phone, :string
    add_column :clubs, :email, :string
    add_column :clubs, :website, :string
    add_column :clubs, :address, :string
    add_column :clubs, :city, :string
    add_column :clubs, :state, :string
    add_column :clubs, :country, :string
    add_column :clubs, :timezone, :string
    add_column :clubs, :theme_primary, :string
  end
end
