# Una dispensa anulada dice POR QUÉ, QUIÉN y CUÁNDO (Germán, 13-sep-2026). Hasta acá el motivo
# vivía enterrado en el json de `historial_envio` —imposible de filtrar o contar— y la puerta
# más usada («Eliminar») no pedía ninguno y soft-borraba la fila: la dispensa desaparecía sin
# rastro, que es justo lo que un auditor pregunta.
class AddAnulacionADispensaciones < ActiveRecord::Migration[7.2]
  def change
    add_column    :dispensaciones, :motivo_anulacion, :string
    add_column    :dispensaciones, :nota_anulacion,   :text
    add_column    :dispensaciones, :anulada_at,       :datetime
    add_reference :dispensaciones, :anulada_por, foreign_key: { to_table: :users }, null: true
    add_index     :dispensaciones, :motivo_anulacion
  end
end
