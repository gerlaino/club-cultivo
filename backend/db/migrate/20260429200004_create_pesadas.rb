class CreatePesadas < ActiveRecord::Migration[7.2]
  def change
    create_table :pesadas do |t|
      t.references :lote,          null: false, foreign_key: true
      t.references :registrado_por, null: false, foreign_key: { to_table: :users }
      t.string     :fase_origen,   null: false
      t.string     :fase_destino,  null: false
      t.decimal    :peso_humedo_g, precision: 10, scale: 2
      t.decimal    :peso_seco_g,   precision: 10, scale: 2
      t.decimal    :peso_curado_g, precision: 10, scale: 2
      t.boolean    :manicurado,    default: false, null: false
      t.text       :notas
      t.datetime   :registrado_at, null: false
      t.timestamps
    end

    add_index :pesadas, [:lote_id, :registrado_at]

    create_table :pesadas_plantas do |t|
      t.references :pesada, null: false, foreign_key: true
      t.references :plant,  null: false, foreign_key: true
      t.decimal    :peso_humedo_g, precision: 8, scale: 2
      t.decimal    :peso_seco_g,   precision: 8, scale: 2
      t.timestamps
    end

    # Extender estados válidos de lotes con 'secado'
    # (solo el modelo lo valida; el schema es open string, no enum)
  end
end
