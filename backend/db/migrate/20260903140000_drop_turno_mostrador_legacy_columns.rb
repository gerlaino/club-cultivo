# LO QUE QUEDÓ COLGANDO DEL MODELO VIEJO (antes de `CreateMostradorItems`, sep-2026), donde el
# turno era el contenido de la mesa y no sólo su arqueo. Nada de esto se escribe más — se
# verificó con un grep sobre `app/`, `lib/` y `spec/` antes de tocar el esquema.
#
# `turno_mostrador_movimientos` registraba cada carga y devolución DE UN TURNO. Lo reemplazó
# `mostrador_movimientos`, que es de la MESA y no del turno. Se borra la tabla entera — el modelo
# (`TurnoMostradorMovimiento`) queda marcado NO USAR EN CÓDIGO NUEVO y se elimina en este mismo
# commit.
#
# De `turno_mostrador_items` se van CUATRO columnas:
#   · `cantidad_repuesta`, `cantidad_devuelta`, `cantidad_ajuste` — eran los tres números con los
#     que se calculaba `esperado` cuando el turno ERA la mesa. Con `MostradorItem#cantidad` como
#     única fuente de lo que hay, no hay nada que sumar.
#   · `cantidad_heredada` — es el mismo número que `esperado_apertura`, y la migración anterior
#     (`CreateMostradorItems`) ya copió ahí el valor de todo turno que lo tuviera. No se pierde
#     nada: es la columna que sobra cuando el mismo dato vivía escrito dos veces.
#
# Reversible como CÓDIGO, no como DATOS: `down` recrea las columnas y la tabla vacías, no lo que
# había en ellas — mismo criterio que `CreateMostradorItems#down`.
class DropTurnoMostradorLegacyColumns < ActiveRecord::Migration[7.2]
  def up
    drop_table :turno_mostrador_movimientos

    remove_column :turno_mostrador_items, :cantidad_repuesta, :decimal
    remove_column :turno_mostrador_items, :cantidad_devuelta, :decimal
    remove_column :turno_mostrador_items, :cantidad_ajuste, :decimal
    remove_column :turno_mostrador_items, :cantidad_heredada, :decimal
  end

  def down
    add_column :turno_mostrador_items, :cantidad_heredada, :decimal, precision: 10, scale: 3
    add_column :turno_mostrador_items, :cantidad_ajuste, :decimal, precision: 10, scale: 3,
               default: '0.0', null: false
    add_column :turno_mostrador_items, :cantidad_devuelta, :decimal, precision: 10, scale: 3,
               default: '0.0', null: false
    add_column :turno_mostrador_items, :cantidad_repuesta, :decimal, precision: 10, scale: 3,
               default: '0.0', null: false

    create_table :turno_mostrador_movimientos do |t|
      t.references :club, null: false, foreign_key: true
      t.references :turno_mostrador_item, null: false, foreign_key: { to_table: :turno_mostrador_items }
      t.references :usuario, null: false, foreign_key: { to_table: :users }
      t.string :tipo, null: false
      t.decimal :cantidad, precision: 10, scale: 3, null: false
      t.boolean :sin_supervision, default: false, null: false
      t.string :notas
      t.timestamps
    end
    add_index :turno_mostrador_movimientos, %i[turno_mostrador_item_id], name: 'index_tmm_on_item'
  end
end
