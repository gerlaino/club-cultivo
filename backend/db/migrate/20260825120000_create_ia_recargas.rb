# Créditos de IA vendidos aparte del plan.
#
# El tope mensual sale del plan (Básico 500 / Total 2.000). Cuando una organización se queda
# corta, el super admin le carga créditos extra y esos se COBRAN aparte — así que hace falta
# saber cuántos, cuándo y quién los cargó. Una columna con un número suelto en `clubs` no
# alcanzaba: no se puede facturar de memoria, y alguien tendría que acordarse de ponerla en
# cero el día 1 de cada mes o los créditos quedarían regalados para siempre.
#
# Con una fila por recarga, los créditos vencen solos: el tope del mes suma únicamente las
# recargas de ESE mes.
class CreateIaRecargas < ActiveRecord::Migration[7.2]
  def change
    create_table :ia_recargas do |t|
      t.references :club, null: false, foreign_key: true
      # Quién la cargó, para que el historial tenga responsable. `nullable` porque una recarga
      # hecha por un rake o una migración no tiene persona detrás.
      t.references :user, null: true, foreign_key: true

      t.integer :creditos, null: false
      # El mes al que aplican, siempre el día 1. No se acumulan: lo que no se usó, se perdió.
      t.date    :mes,      null: false
      # Para qué fue. Es lo que se lee al facturar: "compró 500 para la campaña de agosto".
      t.string  :nota

      t.timestamps
    end

    add_index :ia_recargas, [:club_id, :mes]
  end
end
