class CreateUserSedes < ActiveRecord::Migration[7.2]
  def change
    create_table :user_sedes, if_not_exists: true do |t|
      t.references :user, null: false, foreign_key: true
      t.references :sede, null: false, foreign_key: true
      t.timestamps
    end
    add_index :user_sedes, [:user_id, :sede_id], unique: true, if_not_exists: true
  end
end