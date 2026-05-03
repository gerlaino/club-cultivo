class DropSedeInventariosCreateStocks < ActiveRecord::Migration[7.2]
  def up
    # 1. Romper FK de dispensaciones → sede_inventarios antes de poder dropear
    remove_foreign_key :dispensaciones, :sede_inventarios if foreign_key_exists?(:dispensaciones, :sede_inventarios)
    remove_column :dispensaciones, :sede_inventario_id

    # 2. inventario_movimientos tiene FK → sede_inventarios; dropear tabla entera
    drop_table :inventario_movimientos

    # 3. Ahora sede_inventarios no tiene referencias entrantes
    drop_table :sede_inventarios

    # 4. Nueva tabla stocks
    create_table :stocks do |t|
      t.references :sede,  null: false, foreign_key: true
      t.string     :origen, null: false
        # lote | derivado_lote | compra_externa
      t.references :lote,   foreign_key: true
      t.decimal    :lote_origen_consumido_g, precision: 10, scale: 2
      t.string     :forma_producto, null: false
        # flor_seca | hash | aceite | tintura | crema | capsula | comestible | prensado | otro | externo
      t.string     :unidad, null: false, default: 'g'   # g | ml | un
      t.decimal    :cantidad,            precision: 10, scale: 2, null: false
      t.decimal    :costo_unitario_ars,  precision: 10, scale: 2
      t.decimal    :precio_sugerido_ars, precision: 10, scale: 2
      t.string     :proveedor
      t.string     :descripcion
      t.string     :categoria    # merch | bebida | insumo | otros
      t.timestamps
    end

    add_index :stocks, [:lote_id, :forma_producto]
    add_index :stocks, :origen
    add_index :stocks, [:sede_id, :origen]

    # 5. dispensaciones ahora referencian stock
    add_column     :dispensaciones, :stock_id, :bigint
    add_foreign_key :dispensaciones, :stocks, on_delete: :nullify
    add_index      :dispensaciones, :stock_id
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
