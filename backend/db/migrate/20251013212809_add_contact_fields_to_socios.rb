class AddContactFieldsToSocios < ActiveRecord::Migration[7.2]
  def change
    add_column :socios, :email, :string
    add_column :socios, :telefono, :string
  end
end
