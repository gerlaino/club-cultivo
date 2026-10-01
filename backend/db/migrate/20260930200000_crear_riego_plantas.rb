# El riego POR PLANTA (Germán, 30-sep-2026). El riego sigue siendo UN registro del lote
# (`registros_ambientales`); cuando no se regó todo el lote parejo, esta tabla dice qué plantas
# recibieron agua y cuánta: unas 1 pulso, otras 2. El total del lote es la suma. Lo que se cargó
# en pulsos guarda también los pulsos y a cuántos litros equivalía uno, para que el historial
# diga «2 pulsos» y los litros se puedan sumar y comparar.
class CrearRiegoPlantas < ActiveRecord::Migration[7.2]
  def change
    create_table :riego_plantas do |t|
      t.references :club,               null: false, foreign_key: true
      t.references :registro_ambiental, null: false, foreign_key: { to_table: :registros_ambientales }
      t.references :plant,              null: false, foreign_key: true
      t.decimal :volumen_l,        precision: 10, scale: 2, null: false
      t.decimal :pulsos,           precision: 8,  scale: 2
      t.decimal :litros_por_pulso, precision: 8,  scale: 3
      t.timestamps
    end
    add_index :riego_plantas, %i[registro_ambiental_id plant_id], unique: true
  end
end
