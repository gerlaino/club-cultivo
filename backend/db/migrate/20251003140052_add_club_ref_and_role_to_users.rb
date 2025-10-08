class AddClubRefAndRoleToUsers < ActiveRecord::Migration[7.2]
  def change
    add_reference :users, :club, null: false, foreign_key: true
    add_column :users, :role, :string, null: false, default: "cultivador"
    add_index :users, :role
  end
end
