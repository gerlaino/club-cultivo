class AddProducidoDesdeStockToStocks < ActiveRecord::Migration[7.2]
  # Vincula un stock derivado (producido vía POST /stocks/:id/producir) con el stock de origen
  # del que consumió gramos. Sin esto, borrar el derivado no podía devolver los gramos usados
  # (el origen externo ni siquiera quedaba referenciado). Los gramos consumidos se guardan en
  # lote_origen_consumido_g (ya existente) para ambos casos (de lote y externo).
  def change
    add_reference :stocks, :producido_desde_stock, null: true,
                  foreign_key: { to_table: :stocks }
  end
end
