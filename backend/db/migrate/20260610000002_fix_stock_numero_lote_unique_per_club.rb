class FixStockNumeroLoteUniquePerClub < ActiveRecord::Migration[7.1]
  def up
    remove_index :stocks, name: "index_stocks_on_numero_lote_producto"
    add_index :stocks, [:club_id, :numero_lote_producto],
              name: "index_stocks_on_club_id_and_numero_lote_producto",
              unique: true,
              where: "numero_lote_producto IS NOT NULL"
  end

  def down
    remove_index :stocks, name: "index_stocks_on_club_id_and_numero_lote_producto"
    add_index :stocks, :numero_lote_producto,
              name: "index_stocks_on_numero_lote_producto",
              unique: true,
              where: "numero_lote_producto IS NOT NULL"
  end
end
