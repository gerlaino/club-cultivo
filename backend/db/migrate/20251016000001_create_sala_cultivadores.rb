class CreateSalaCultivadores < ActiveRecord::Migration[7.2]
  def change
    create_table :sala_cultivadores do |t|
      t.references :sala, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end

    add_index :sala_cultivadores, [:sala_id, :user_id], unique: true
  end
end