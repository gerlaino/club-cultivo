# Multi-sede: el depósito pasa a ser de una SEDE (antes era del club, con la sede en el ítem).
# Cada sede tiene sus depósitos (General siempre; Cultivo en producción; Salón/Dispensario en
# social/mixta). La sede-ificación de los datos existentes la hace Finanzas::SembrarDepositos
# (idempotente): crea los depósitos por sede, reasigna los insumos y retira los club-wide viejos.
class AddSedeADepositos < ActiveRecord::Migration[7.2]
  def change
    add_reference :depositos, :sede, foreign_key: true, null: true
    add_index :depositos, %i[club_id sede_id clave_sistema], name: 'index_depositos_on_club_sede_clave'
  end
end
