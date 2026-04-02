class CreateRegistrosAmbientales < ActiveRecord::Migration[7.2]
  def change
    create_table :registros_ambientales do |t|
      t.references :lote,    null: false, foreign_key: true
      t.references :user,    null: false, foreign_key: true
      t.references :club,    null: false, foreign_key: true

      # Ambiente
      t.decimal :temperatura,   precision: 5, scale: 2   # °C
      t.decimal :humedad,       precision: 5, scale: 2   # %
      t.decimal :vpd,           precision: 5, scale: 3   # kPa
      t.decimal :co2,           precision: 7, scale: 1   # ppm
      t.decimal :ph,            precision: 4, scale: 2   # 0-14
      t.decimal :ec,            precision: 5, scale: 2   # mS/cm

      # Luz
      t.decimal :horas_luz,     precision: 4, scale: 1   # horas/día
      t.string  :espectro_luz                             # veg / bloom / auto

      # Nutrición
      t.string  :fase_nutricional                        # crecimiento/floración/engorde/lavado
      t.decimal :ml_nutrientes_litro, precision: 6, scale: 2

      # Plaga / salud general
      t.string  :estado_general   # excelente / bueno / regular / malo / critico
      t.text    :observaciones

      t.datetime :registrado_en, null: false

      t.timestamps
    end

    add_index :registros_ambientales, :lote_id, if_not_exists: true
    add_index :registros_ambientales, :registrado_en, if_not_exists: true
  end
end