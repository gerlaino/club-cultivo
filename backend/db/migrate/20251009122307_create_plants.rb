class CreatePlants < ActiveRecord::Migration[7.2]
  def change
    create_table :plants do |t|
      t.references :lote, null: false, foreign_key: true
      t.string :code
      t.string :strain
      t.string :stage
      t.string :health
      t.string :photo_url
      t.text :notes
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
