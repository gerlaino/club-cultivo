# Recetas de nutrientes (20-sep-2026): «armar receta» y «aplicar receta» al regar. Una receta es
# una lista de insumos del depósito con su dosis por litro; al aplicarla con N litros se calcula
# cuánto de cada uno, se descuenta del depósito y el costo cae al lote. El registro de riego
# guarda una COPIA de lo aplicado (`nutricion`): si después se edita la receta, el historial no
# cambia. `insumo_consumos.registro_ambiental_id` permite revertir al borrar el registro.
class CrearRecetasNutrientes < ActiveRecord::Migration[7.2]
  def change
    create_table :recetas do |t|
      t.references :club, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.string  :nombre, null: false
      t.string  :fase                         # vegetativo · floracion · lavado · otra
      t.decimal :ph_objetivo, precision: 4, scale: 2
      t.decimal :ec_objetivo, precision: 5, scale: 2
      t.text    :notas
      t.boolean :activa, null: false, default: true
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :recetas, [:club_id, :nombre]
    add_index :recetas, :deleted_at

    create_table :receta_items do |t|
      t.references :receta, null: false, foreign_key: { to_table: :recetas }
      t.references :insumo, null: false, foreign_key: true
      t.decimal :dosis, precision: 10, scale: 3, null: false
      t.string  :unidad, null: false, default: 'ml_l'   # ml_l · g_l
      t.integer :orden, null: false, default: 0
      t.timestamps
    end

    add_reference :registros_ambientales, :receta, foreign_key: { to_table: :recetas }
    add_column    :registros_ambientales, :litros, :decimal, precision: 8, scale: 2
    add_column    :registros_ambientales, :nutricion, :jsonb

    add_reference :insumo_consumos, :registro_ambiental, foreign_key: { to_table: :registros_ambientales }
  end
end
