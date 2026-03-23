# backend/db/migrate/20260320000002_create_costo_lotes.rb
class CreateCostoLotes < ActiveRecord::Migration[7.2]
  def change
    create_table :costo_lotes do |t|
      t.bigint  :lote_id, null: false
      t.bigint  :club_id, null: false

      # Costos desglosados (todos en ARS)
      t.decimal :costo_insumos,     precision: 12, scale: 2, default: 0, null: false
      t.decimal :costo_energia,     precision: 12, scale: 2, default: 0, null: false
      t.decimal :costo_mano_obra,   precision: 12, scale: 2, default: 0, null: false
      t.decimal :costo_prorrateado, precision: 12, scale: 2, default: 0, null: false
      t.decimal :costo_total,       precision: 12, scale: 2, default: 0, null: false

      # Producción
      t.decimal  :gramos_producidos, precision: 10, scale: 2
      t.decimal  :costo_por_gramo,   precision: 10, scale: 2

      # Metadata
      t.text     :notas
      t.bigint   :calculado_por_id
      t.datetime :calculado_at

      t.timestamps
    end

    add_index :costo_lotes, :lote_id, unique: true, if_not_exists: true
    add_index :costo_lotes, :club_id,               if_not_exists: true

    add_foreign_key :costo_lotes, :lotes
    add_foreign_key :costo_lotes, :clubs
    add_foreign_key :costo_lotes, :users, column: :calculado_por_id
  end
end