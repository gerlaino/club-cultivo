class AddSalasToLoteEventos < ActiveRecord::Migration[7.2]
  def change
    add_reference :lote_eventos, :sala_origen,  foreign_key: { to_table: :salas }, null: true
    add_reference :lote_eventos, :sala_destino, foreign_key: { to_table: :salas }, null: true
  end
end
