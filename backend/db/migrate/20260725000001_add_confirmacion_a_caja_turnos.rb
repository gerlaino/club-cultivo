# Caja de turno con confirmación entre roles (B5 del rediseño del Salón):
# - la apertura la hace admin/supervisor y el dispensador CONFIRMA que está la plata;
# - el cierre lo SOLICITA el dispensador (cuenta el efectivo) y admin/supervisor lo CONFIRMA,
#   o admin/supervisor cierra directo. Estado intermedio: 'pendiente_cierre'.
class AddConfirmacionACajaTurnos < ActiveRecord::Migration[7.2]
  def up
    add_reference :caja_turnos, :apertura_confirmada_por, foreign_key: { to_table: :users }, null: true
    add_column    :caja_turnos, :apertura_confirmada_at, :datetime
    add_reference :caja_turnos, :cierre_solicitado_por,  foreign_key: { to_table: :users }, null: true
    add_column    :caja_turnos, :cierre_solicitado_at,   :datetime

    # La unicidad de "una caja activa por bar" ahora incluye el estado intermedio pendiente_cierre,
    # para que no se abra una caja nueva mientras hay un cierre esperando confirmación.
    remove_index :caja_turnos, name: "index_caja_turnos_una_abierta_por_bar"
    add_index :caja_turnos, :bar_id, unique: true, name: "index_caja_turnos_activa_por_bar",
              where: "((estado)::text = ANY (ARRAY['abierta'::text, 'pendiente_cierre'::text]))"
  end

  def down
    remove_index :caja_turnos, name: "index_caja_turnos_activa_por_bar"
    add_index :caja_turnos, :bar_id, unique: true, name: "index_caja_turnos_una_abierta_por_bar",
              where: "((estado)::text = 'abierta'::text)"
    remove_column :caja_turnos, :cierre_solicitado_at
    remove_reference :caja_turnos, :cierre_solicitado_por
    remove_column :caja_turnos, :apertura_confirmada_at
    remove_reference :caja_turnos, :apertura_confirmada_por
  end
end
