class AddLoteNumeroSeqToClubs < ActiveRecord::Migration[7.0]
  def up
    add_column :clubs, :lote_numero_seq, :integer, default: 0, null: false

    # Seed each club's sequence with its current stock count so existing
    # numbers don't collide with future ones.
    execute <<~SQL
      UPDATE clubs
      SET lote_numero_seq = (
        SELECT COUNT(*) FROM stocks WHERE stocks.club_id = clubs.id
      )
    SQL
  end

  def down
    remove_column :clubs, :lote_numero_seq
  end
end
