# Suelo vivo: las CAMAS de cultivo (Germán, 22/25-sep-2026; plan en `docs/PLAN_SUELO_VIVO.md`).
#
# En suelo vivo el sustrato no nace y muere con el lote: la cama dura años, por ella pasan muchos
# lotes, se alimenta (top dress, tés, cobertura, mulch) y descansa entre cosechas. Por eso es una
# entidad propia y no un dato del lote:
#
# - `camas`: dónde está (sala), cuánto mide (largo × ancho × profundidad: los m² y los litros de
#   suelo se calculan), con qué se armó (copia de la mezcla), y sus tiempos. Los números de cultivo
#   —semanas de cocción, días de descanso, cada cuántos días toca top dress— los pone el
#   cultivador: la app no trae ninguno de fábrica (Germán, 25-sep).
# - `cama_ciclos`: de que se planta el primer lote hasta que sale el último. Es lo que permite
#   comparar «ciclo 3: 480 g/m², ciclo 2: 410» de la misma cama.
# - `cama_registros`: todo lo que se le hace AL SUELO, haya o no lotes adentro.
# - `analisis_suelo`: el análisis de laboratorio del suelo (el de la flor es otra tabla).
# - `lotes.cama_id` / `cama_ciclo_id`: en qué cama y en qué ciclo creció. Se conservan al cosechar
#   (son historia, como los m² congelados).
# - `recetas.uso`: riego (lo de siempre, incluye los tés) · top_dress (dosis por m²) · mezcla
#   (dosis por litro de suelo).
# - `insumo_consumos.cama_id` / `cama_registro_id`: lo que se le puso a la cama, para el costo y
#   para «¿qué comió esta flor?».
# - `registros_ambientales.agua`: qué agua se usó al regar (el cloro mata la vida del suelo).
class CrearCamasSueloVivo < ActiveRecord::Migration[7.2]
  def change
    create_table :camas do |t|
      t.references :club, null: false, foreign_key: true
      t.references :sala, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.string  :nombre, null: false
      t.decimal :largo_m,        precision: 6, scale: 2
      t.decimal :ancho_m,        precision: 6, scale: 2
      t.decimal :profundidad_cm, precision: 6, scale: 1
      t.date    :armada_el
      t.integer :semanas_coccion
      t.date    :cocina_hasta
      t.integer :dias_descanso
      t.integer :frecuencia_top_dress_dias
      t.date    :descansa_desde
      t.date    :descansa_hasta
      t.date    :retirada_el
      t.jsonb   :mezcla
      t.text    :notas
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :camas, :deleted_at
    add_index :camas, [:sala_id, :nombre], unique: true, where: 'deleted_at IS NULL',
              name: 'index_camas_nombre_unico_por_sala'

    create_table :cama_ciclos do |t|
      t.references :club, null: false, foreign_key: true
      t.references :cama, null: false, foreign_key: true
      t.integer :numero, null: false
      t.date    :desde,  null: false
      t.date    :hasta
      t.timestamps
    end
    add_index :cama_ciclos, [:cama_id, :numero], unique: true

    add_reference :lotes, :cama,        foreign_key: true
    add_reference :lotes, :cama_ciclo,  foreign_key: true

    create_table :cama_registros do |t|
      t.references :club, null: false, foreign_key: true
      t.references :cama, null: false, foreign_key: true
      t.references :cama_ciclo, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :receta, foreign_key: { to_table: :recetas }
      t.string   :tipo, null: false
      t.datetime :registrado_en, null: false
      t.boolean  :recarga, null: false, default: false
      t.string   :detalle                     # qué: «trébol blanco», «paja de alfalfa», «micorrizas»
      t.decimal  :cantidad, precision: 10, scale: 2
      t.string   :unidad                      # de `cantidad` (g, kg, L, cm…), texto corto
      t.decimal  :litros,   precision: 8,  scale: 2
      t.string   :agua
      t.decimal  :humedad_suelo,     precision: 5, scale: 1
      t.decimal  :temperatura_suelo, precision: 5, scale: 1
      t.jsonb    :nutricion
      t.text     :observaciones
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :cama_registros, [:cama_id, :registrado_en]
    add_index :cama_registros, :deleted_at

    create_table :analisis_suelo do |t|
      t.references :club, null: false, foreign_key: true
      t.references :cama, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.date    :fecha, null: false
      t.string  :laboratorio
      t.decimal :ph,                  precision: 4, scale: 2
      t.decimal :ce,                  precision: 6, scale: 2   # dS/m
      t.decimal :materia_organica_pct, precision: 5, scale: 2
      t.decimal :nitrogeno_pct,       precision: 6, scale: 3
      t.decimal :fosforo_ppm,         precision: 8, scale: 2
      t.decimal :potasio_ppm,         precision: 8, scale: 2
      t.decimal :calcio_ppm,          precision: 8, scale: 2
      t.decimal :magnesio_ppm,        precision: 8, scale: 2
      t.decimal :cic,                 precision: 6, scale: 2   # cmol/kg
      t.decimal :relacion_cn,         precision: 6, scale: 2
      t.decimal :plomo_ppm,           precision: 8, scale: 3
      t.decimal :cadmio_ppm,          precision: 8, scale: 3
      t.decimal :arsenico_ppm,        precision: 8, scale: 3
      t.decimal :mercurio_ppm,        precision: 8, scale: 3
      t.text    :notas
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :analisis_suelo, :deleted_at

    add_column :recetas, :uso, :string, null: false, default: 'riego'

    add_reference :insumo_consumos, :cama, foreign_key: true
    add_reference :insumo_consumos, :cama_registro, foreign_key: true

    add_column :registros_ambientales, :agua, :string
  end
end
