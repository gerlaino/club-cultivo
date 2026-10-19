# «En revisión por X» en un pesaje de manicura (16-oct-2026, Javi: «si mientras el admin está
# armando los frascos confirmando el pesaje, manicura cambia el peso, y el admin confirma, se crea
# con los pesajes nuevos… al abrir para confirmar se debería bloquear al manicura»).
#
# Quién abrió «Confirmar» y cuándo. Mientras dure (se libera al cerrar, al confirmar o a los 15
# minutos: `PesajeManicura::REVISION_DURA`), nadie más lo reabre ni lo borra.
class AgregarRevisionAPesajesManicura < ActiveRecord::Migration[7.2]
  def change
    add_reference :pesajes_manicura, :revisando_por, foreign_key: { to_table: :users }, null: true
    add_column    :pesajes_manicura, :revisando_at, :datetime
  end
end
