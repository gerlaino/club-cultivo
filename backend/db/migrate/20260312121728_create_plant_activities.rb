class CreatePlantActivities < ActiveRecord::Migration[7.2]
  def change
    create_table :plant_activities do |t|
      t.references :plant, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :activity_type, null: false
      t.text :description
      t.jsonb :metadata, default: {}
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :plant_activities, :activity_type
    add_index :plant_activities, :occurred_at
  end
end
