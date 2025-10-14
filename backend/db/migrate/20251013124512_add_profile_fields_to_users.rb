class AddProfileFieldsToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :dni, :string
    add_column :users, :birth_date, :date
    add_column :users, :phone, :string
  end
end
