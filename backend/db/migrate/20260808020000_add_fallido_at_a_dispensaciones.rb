class AddFallidoAtADispensaciones < ActiveRecord::Migration[7.2]
  # Una entrega que se concreta guarda `entregado_at`. Una que falla no guardaba NADA: sólo
  # el estado y el motivo. La única marca temporal era `updated_at`, que cambia con cualquier
  # edición posterior, así que el historial del repartidor no podía filtrar bien por fecha —
  # un fallo de hace dos meses que después se tocó volvía a caer dentro de "últimos 7 días".
  def change
    add_column :dispensaciones, :fallido_at, :datetime

    # Los fallos que ya existen no tienen cuándo: se usa `updated_at` como mejor aproximación
    # disponible. Es lo mismo que el filtro venía usando, así que no empeora nada y a partir
    # de acá los nuevos quedan bien.
    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE dispensaciones
             SET fallido_at = updated_at
           WHERE estado_envio = 'fallido'
             AND fallido_at IS NULL
        SQL
      end
    end
  end
end
