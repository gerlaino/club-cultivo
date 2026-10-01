# REPARTIR UN PESAJE EN VARIOS FRASCOS (Germán, 1-oct-2026): el admin confirma un pesaje de
# manicura y lo separa —copones en un frasco, bajos en otro, para venderlos a distinto precio—.
# Todo sigue siendo del mismo lote (la trazabilidad no cambia); esta tabla dice cuántos gramos del
# pesaje fueron a cada frasco. `pesajes_manicura.stock_id` queda como el primero, por compatibilidad;
# los pesajes viejos (sin filas acá) se leen como un único destino con todo el peso.
class CrearPesajeDestinos < ActiveRecord::Migration[7.2]
  def change
    create_table :pesaje_destinos do |t|
      t.references :club,            null: false, foreign_key: true
      t.references :pesaje_manicura, null: false, foreign_key: { to_table: :pesajes_manicura }
      t.references :stock,           null: false, foreign_key: true
      t.decimal :gramos, precision: 10, scale: 2, null: false
      t.timestamps
    end
    add_index :pesaje_destinos, %i[pesaje_manicura_id stock_id], unique: true
  end
end
