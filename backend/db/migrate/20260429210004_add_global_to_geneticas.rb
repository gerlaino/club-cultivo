class AddGlobalToGeneticas < ActiveRecord::Migration[7.2]
  def up
    change_column_null :geneticas, :club_id, true
    add_column :geneticas, :global, :boolean, default: false, null: false
    execute "UPDATE geneticas SET global = true, club_id = NULL"
  end

  def down
    club_id = Club.order(:id).first&.id || 1
    execute "UPDATE geneticas SET club_id = #{club_id} WHERE club_id IS NULL"
    remove_column :geneticas, :global
    change_column_null :geneticas, :club_id, false
  end
end
