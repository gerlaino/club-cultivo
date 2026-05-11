class AddClubIdAndDeletedAtToPlants < ActiveRecord::Migration[7.2]
  def up
    add_column :plants, :club_id,    :bigint
    add_column :plants, :deleted_at, :datetime

    execute <<~SQL
      UPDATE plants
      SET club_id = lotes.club_id
      FROM lotes
      WHERE plants.lote_id = lotes.id
    SQL

    add_index :plants, :club_id
    add_index :plants, :deleted_at
    add_foreign_key :plants, :clubs
  end

  def down
    remove_foreign_key :plants, :clubs
    remove_column :plants, :club_id
    remove_column :plants, :deleted_at
  end
end
