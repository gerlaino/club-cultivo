class CreateLotes < ActiveRecord::Migration[7.2]
  def change
    create_table :lotes do |t|
      t.string :code
      t.date :start_date
      t.string :stage
      t.integer :plants_count
      t.string :strain
      t.text :notes
      t.references :sala, null: false, foreign_key: true
      t.references :club, null: false, foreign_key: true

      t.timestamps
    end
  end
end
