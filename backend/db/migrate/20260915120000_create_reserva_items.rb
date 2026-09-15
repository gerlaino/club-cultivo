# Una reserva pasa a tener LÍNEAS, como la dispensa (Germán, 15-sep-2026): el carrito que ya
# existe al dispensar sirve también al reservar. Gemela de `dispensacion_items`.
#
# `reservas.stock_id` y `reservas.cantidad` QUEDAN con el mismo significado que en
# `dispensaciones`: primera línea y suma de las líneas. Lo que suma stock apartado por reserva
# (`Stock#apartado_para_reservas`) deja de leer esas columnas y lee las líneas.
#
# Backfill: cada reserva existente —también las entregadas, canceladas y borradas, para que la
# historia se lea igual que lo nuevo— genera UNA línea con su stock y su cantidad.
class CreateReservaItems < ActiveRecord::Migration[7.2]
  def up
    create_table :reserva_items do |t|
      t.references :reserva, null: false, foreign_key: true
      t.references :stock,   null: true,  foreign_key: true
      t.decimal :cantidad,            precision: 10, scale: 3, null: false, default: 0
      t.decimal :precio_unitario_ars, precision: 10, scale: 2
      t.string  :lote_codigo
      t.string  :genetica_nombre
      t.timestamps
    end

    execute <<~SQL
      INSERT INTO reserva_items (reserva_id, stock_id, cantidad, lote_codigo, genetica_nombre, created_at, updated_at)
      SELECT r.id, r.stock_id, r.cantidad, l.codigo, COALESCE(g.nombre, gl.nombre), r.created_at, r.created_at
      FROM reservas r
      LEFT JOIN stocks   s  ON s.id  = r.stock_id
      LEFT JOIN lotes    l  ON l.id  = s.lote_id
      LEFT JOIN geneticas g ON g.id  = s.genetica_id
      LEFT JOIN geneticas gl ON gl.id = l.genetica_id
    SQL
  end

  def down
    drop_table :reserva_items
  end
end
