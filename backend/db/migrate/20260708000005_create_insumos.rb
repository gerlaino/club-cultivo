class CreateInsumos < ActiveRecord::Migration[7.2]
  # Insumo de cultivo (fertilizante, sustrato, macetas…). Depósito con costeo por
  # promedio ponderado móvil: `costo_promedio_ars` se recalcula en cada compra.
  def change
    create_table :insumos do |t|
      t.references :club,              null: false, foreign_key: true
      t.references :categoria_contable, null: true, foreign_key: { to_table: :categorias_contables }
      t.string  :nombre,             null: false
      t.string  :unidad_medida,      null: false, default: 'unidad'
      t.decimal :stock_actual,       precision: 14, scale: 3, null: false, default: 0
      t.decimal :costo_promedio_ars, precision: 14, scale: 4, null: false, default: 0
      t.decimal :stock_minimo,       precision: 14, scale: 3, null: false, default: 0
      t.boolean :activo,             null: false, default: true
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :insumos, :deleted_at
    add_index :insumos, [:club_id, :nombre]
  end
end
