class AllowNullSalaIdOnLotes < ActiveRecord::Migration[7.2]
  def up
    change_column_null :lotes, :sala_id, true
  end

  def down
    execute "UPDATE lotes SET sala_id = (SELECT MIN(id) FROM salas WHERE salas.club_id = lotes.club_id) WHERE sala_id IS NULL"
    change_column_null :lotes, :sala_id, false
  end
end
