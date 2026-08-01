# El domo deja de ser una entidad. No aportaba ninguna decisión que el ESTADO del lote no diera ya:
# "enraizado" significa exactamente eso —otro clima, otra luz, todavía no come—, y modelar el
# aparato solo agregaba administración (crearlo, elegirlo, mudarlo, liberarlo, archivarlo).
#
# Lo que el domo prometía era atribuir el prendimiento al hardware ("se murió la manta térmica de
# ese propagador"). Eso ya estaba comprometido: en el domo real conviven varias genéticas, y con un
# clonador por lote el patrón del aparato quedaba diluido en varios clonadores lógicos. El día que
# haga falta, se recupera con UN CAMPO (un `propagador` en el registro ambiental), no con una tabla.
#
# Se conservan `producto_enraizante` y `temperatura_sustrato` en registros_ambientales: son del
# ENRAIZADO, no del domo, y siguen siendo lo que explica por qué prende o no.
class EliminarClonadores < ActiveRecord::Migration[7.2]
  # Sin la regla de inflexión (que se va con el modelo), Rails pluraliza "clonador" como
  # "clonadors" y `remove_reference ..., foreign_key: true` busca una tabla que no existe. Por eso
  # acá la FK y la columna se nombran explícitamente, sin depender del inflector.
  def up
    remove_foreign_key :registros_ambientales, column: :clonador_id
    remove_column      :registros_ambientales, :clonador_id
    remove_foreign_key :lotes, column: :clonador_id
    remove_column      :lotes, :clonador_id
    drop_table :clonadores
  end

  def down
    create_table :clonadores do |t|
      t.references :club, null: false, foreign_key: true
      t.references :sala, null: false, foreign_key: true
      t.string   :nombre, null: false
      t.integer  :capacidad
      t.boolean  :activo, null: false, default: true
      t.datetime :deleted_at
      t.references :deleted_by, null: true, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :clonadores, :deleted_at
    add_reference :lotes,                 :clonador, null: true, foreign_key: { to_table: :clonadores }
    add_reference :registros_ambientales, :clonador, null: true, foreign_key: { to_table: :clonadores }
  end
end
