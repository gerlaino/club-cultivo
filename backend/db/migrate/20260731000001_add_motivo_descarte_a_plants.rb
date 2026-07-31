# El motivo del descarte existía solo como TEXTO LIBRE (iba a las notas de la planta y al evento del
# lote). Sirve para leer una planta, no para medir nada: no se puede preguntar "¿cuántos esquejes no
# prendieron?". Este campo estructurado convive con el texto libre, que se queda para el detalle.
#
# El que importa es `no_prendio`: es lo que habilita medir el PRENDIMIENTO, que hasta ahora se perdía
# mezclado con cualquier otro descarte.
class AddMotivoDescarteAPlants < ActiveRecord::Migration[7.2]
  def change
    add_column :plants, :motivo_descarte, :string
    add_index  :plants, :motivo_descarte, where: 'motivo_descarte IS NOT NULL'
  end
end
