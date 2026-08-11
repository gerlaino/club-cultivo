# Un módulo no se apaga en el momento en que se da de baja: la organización lo pagó hasta el fin
# del período, y cortarlo antes es cobrar un mes y no prestarlo.
#
# `features_baja` guarda, por módulo, hasta cuándo sigue andando: `{"delivery": "2026-08-31"}`.
# Mientras esa fecha no pase, `feature?` sigue diciendo que sí. Cuando pasa, un job lo apaga de
# verdad y ejecuta lo que cada módulo tenga que ordenar al irse.
#
# Va como columna aparte y no cambiando los valores de `features` (hoy booleanos) a propósito:
# `features` lo leen decenas de lugares y volverlo un objeto rompería todos.
class AddBajasProgramadasAClubs < ActiveRecord::Migration[7.2]
  def up
    add_column :clubs, :features_baja, :jsonb, null: false, default: {}

    # `delivery` pasa a ser un módulo contratable. Antes venía incluido en la suite de Producción
    # y dispensa, así que TODA organización que la tuviera podía repartir. Sin este backfill, el
    # día del deploy los repartidores no podrían entrar y los repartos en curso quedarían
    # huérfanos — le estaríamos sacando algo que ya usaban.
    #
    # Se prende para quien tenga la suite; darlo de baja después es una decisión comercial, no
    # un efecto secundario de esta migración.
    execute <<~SQL
      UPDATE clubs
         SET features = features || '{"delivery": true}'::jsonb
       WHERE features ->> 'produccion_dispensa' = 'true'
         AND features ->> 'delivery' IS NULL
    SQL
  end

  def down
    remove_column :clubs, :features_baja
  end
end
