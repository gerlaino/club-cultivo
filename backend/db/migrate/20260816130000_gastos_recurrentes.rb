# Los gastos que se repiten, como CATÁLOGO propio: se definen una vez y después se eligen.
#
# Reemplaza al `frecuente` que se agregó unas horas antes, que marcaba un MOVIMIENTO ya cargado.
# Marcar el movimiento sirve, pero no deja curar la lista: no se puede dar de alta "Luz" antes de
# la primera factura, ni corregir el monto de referencia sin cargar un gasto de verdad. Acá el
# molde es una entidad con su propia pantalla, y cada mes se elige y se ajusta el número — la luz
# es fija todos los meses salvo en el monto, que es justamente lo que cambia.
#
# `monto_ars` es una REFERENCIA, no un valor a respetar: el alta lo trae puesto y se corrige. Por
# eso no se genera nada solo — con inflación, un asiento automático es un dato falso (misma razón
# por la que la detección de recurrentes nunca autogeneró nada).
class GastosRecurrentes < ActiveRecord::Migration[7.2]
  def change
    create_table :gastos_recurrentes do |t|
      t.references :club, null: false, foreign_key: true
      t.string  :nombre, null: false                    # "Luz", "Alquiler del galpón"
      t.text    :descripcion                            # lo que se copia a "¿Qué fue?"
      # `to_table` explícito: los dos modelos declaran `self.table_name` en plural irregular
      # (categorias_contables, unidades_negocio) y Rails infiere mal el nombre de la tabla.
      t.references :categoria_contable, foreign_key: { to_table: :categorias_contables }
      t.references :sede,               foreign_key: true
      t.references :unidad_negocio,     foreign_key: { to_table: :unidades_negocio }
      t.decimal :monto_ars, precision: 12, scale: 2     # referencia, editable en cada carga
      t.decimal :cantidad,  precision: 12, scale: 3
      t.string  :unidad
      t.string  :medio_pago
      t.string  :proveedor
      t.boolean :activo, null: false, default: true
      t.integer :orden,  null: false, default: 0
      t.references :created_by, foreign_key: { to_table: :users }
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :gastos_recurrentes, %i[club_id activo orden]
    add_index :gastos_recurrentes, :deleted_at
    # Un nombre por organización: dos "Luz" en el buscador no se distinguen.
    add_index :gastos_recurrentes, %i[club_id nombre], unique: true, where: 'deleted_at IS NULL',
              name: 'index_gastos_recurrentes_nombre_unico'

    # El flag que reemplaza. Se va entero: dejarlo sería tener dos formas de decir lo mismo, que
    # es exactamente lo que veníamos sacando de la app.
    remove_column :movimientos_contables, :frecuente, :boolean, null: false, default: false
  end
end
