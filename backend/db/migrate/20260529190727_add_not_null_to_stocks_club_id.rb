class AddNotNullToStocksClubId < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      UPDATE stocks SET club_id = sedes.club_id
      FROM sedes WHERE stocks.sede_id = sedes.id AND stocks.club_id IS NULL;

      UPDATE stocks SET club_id = lotes.club_id
      FROM lotes WHERE stocks.lote_id = lotes.id AND stocks.club_id IS NULL;
    SQL
    change_column_null :stocks, :club_id, false
  end

  def down
    change_column_null :stocks, :club_id, true
  end
end
