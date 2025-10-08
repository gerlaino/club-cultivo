class CreateSalas < ActiveRecord::Migration[7.2]
  def change
    create_table :salas do |t|
      t.string :name
      t.string :state
      t.integer :pots_count
      t.text :notes
      t.references :club, null: false, foreign_key: true

      t.timestamps
    end
  end
end
