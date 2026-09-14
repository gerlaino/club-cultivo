# Una dispensa anulada por producto defectuoso tiene dos salidas: devolver la plata o cambiar el
# producto (Germán, 14-sep-2026). `resolucion_anulacion` dice cuál se eligió, y la dispensa de
# cambio apunta a la anulada con `reemplaza_a_id`: así se sabe que "cambio pendiente" es una
# anulada con resolución cambio y sin reemplazo todavía.
class AddCambioADispensaciones < ActiveRecord::Migration[7.2]
  def change
    add_column    :dispensaciones, :resolucion_anulacion, :string
    add_reference :dispensaciones, :reemplaza_a, foreign_key: { to_table: :dispensaciones }, null: true
  end
end
