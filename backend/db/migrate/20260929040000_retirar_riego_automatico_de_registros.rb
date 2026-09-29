# Deshace `RiegoAutomaticoEnRegistros` (29-sep-2026): el webhook de riegos de dispositivos se
# retiró el mismo día, antes de usarse (Germán: no es una feature del producto). Un registro vuelve a
# tener siempre una persona como autora.
#
# Los registros sin autor sólo podían venir de ese webhook; se borran para poder volver a exigir
# el autor. En la práctica no hay ninguno: nadie llegó a usarlo.
class RetirarRiegoAutomaticoDeRegistros < ActiveRecord::Migration[7.2]
  def up
    execute 'DELETE FROM registros_ambientales WHERE user_id IS NULL'
    remove_reference :registros_ambientales, :dispositivo, foreign_key: true, index: true
    change_column_null :registros_ambientales, :user_id, false
  end

  def down
    change_column_null :registros_ambientales, :user_id, true
    add_reference :registros_ambientales, :dispositivo, foreign_key: true, null: true, index: true
  end
end
