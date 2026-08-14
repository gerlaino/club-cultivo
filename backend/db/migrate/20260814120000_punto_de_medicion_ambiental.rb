# Dónde se midió el ambiente: en la SALA o dentro de la INCUBADORA (propagador / bandeja de
# enraizado).
#
# El registro ambiental cuelga del LOTE y se propaga a `lecturas_ambientales` con el `sala_id`
# del lote. Un lote enraizando se mide adentro del propagador —28 °C y 90 % de humedad, que es
# justo lo que necesita un esqueje— y ese número salía publicado como el aire del cuarto: el KPI
# de la sala mostraba el clima de la incubadora, y las reglas ambientales de la sala se
# evaluaban contra él (una humedad de propagador dispara la alerta de humedad alta del cuarto
# todas las veces).
#
# El default es 'sala' a propósito: es lo que había hasta hoy y deja el histórico como estaba.
# Lo ya cargado desde una incubadora no se puede distinguir de forma automática —nadie lo
# declaró— así que no se intenta adivinar hacia atrás.
class PuntoDeMedicionAmbiental < ActiveRecord::Migration[7.2]
  def change
    add_column :registros_ambientales, :punto_medicion, :string, null: false, default: 'sala'
    add_column :lecturas_ambientales,  :punto_medicion, :string, null: false, default: 'sala'

    # El KPI de la sala y el evaluador de reglas piden siempre "lo último de ESTE punto":
    # sin el punto en el índice, cada lectura de incubadora obliga a filtrar en memoria.
    add_index :lecturas_ambientales, %i[sala_id punto_medicion tipo medido_at],
              name: 'index_lecturas_sala_punto_tipo_medido'
  end
end
