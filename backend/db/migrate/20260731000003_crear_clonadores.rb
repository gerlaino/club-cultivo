# Un clonador es un domo/propagador DENTRO de una sala, con su propio microclima: el cuarto marca 60%
# de humedad y adentro hay 90%. Sin esto, a los lotes enraizando se les graba el clima de la sala,
# que no es el suyo.
#
# Se modela como entidad porque cumple la regla que nos pusimos para no terminar modelando todo el
# equipamiento: tiene AMBIENTE PROPIO y CAPACIDAD PROPIA. Una lámpara no tiene ninguno de los dos.
class CrearClonadores < ActiveRecord::Migration[7.2]
  def change
    create_table :clonadores do |t|
      t.references :club, null: false, foreign_key: true
      t.references :sala, null: false, foreign_key: true
      t.string  :nombre, null: false
      t.integer :capacidad                       # alvéolos; opcional
      t.boolean :activo, null: false, default: true
      # Soft-delete de la papelera: `Restorable` monta paranoia + `belongs_to :deleted_by`,
      # así que la tabla necesita las DOS columnas, no solo deleted_at.
      t.datetime :deleted_at
      t.references :deleted_by, null: true, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :clonadores, :deleted_at

    # El lote enraizando vive en un clonador. Nullable: no todo lote está en uno.
    add_reference :lotes, :clonador, foreign_key: true, null: true

    # El registro ambiental puede ser del clonador en vez de la sala. Se sigue colgando del lote
    # (que es donde vive la trazabilidad), pero queda etiquetado con el clonador del que salió.
    add_reference :registros_ambientales, :clonador, foreign_key: true, null: true
    # Producto enraizante ESTRUCTURADO: distintos geles/polvos tienen tasas de prendimiento
    # distintas, y así se puede cruzar con el % que ya medimos.
    add_column :registros_ambientales, :producto_enraizante, :string
  end
end
