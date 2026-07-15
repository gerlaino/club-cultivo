class PolimorfizarEventoBarProvisiones < ActiveRecord::Migration[7.2]
  # La provisión de un evento deja de estar atada al depósito del salón: pasa a ser
  # POLIMÓRFICA (BarProducto | Insumo) para poder reservar de bar / cultivo / general.
  # bar_producto_id queda como columna vestigial (nullable) por seguridad de deploy/rollback.
  def up
    add_column :evento_bar_provisiones, :provisionable_type, :string
    add_column :evento_bar_provisiones, :provisionable_id,   :bigint

    execute(<<~SQL)
      UPDATE evento_bar_provisiones
      SET provisionable_type = 'BarProducto', provisionable_id = bar_producto_id
      WHERE bar_producto_id IS NOT NULL
    SQL

    remove_index :evento_bar_provisiones, name: 'index_provisiones_evento_producto'
    add_index :evento_bar_provisiones, [:evento_bar_id, :provisionable_type, :provisionable_id],
              unique: true, name: 'index_provisiones_evento_provisionable'
    add_index :evento_bar_provisiones, [:provisionable_type, :provisionable_id],
              name: 'index_provisiones_on_provisionable'

    change_column_null :evento_bar_provisiones, :bar_producto_id, true
  end

  def down
    remove_index :evento_bar_provisiones, name: 'index_provisiones_on_provisionable'
    remove_index :evento_bar_provisiones, name: 'index_provisiones_evento_provisionable'
    add_index :evento_bar_provisiones, [:evento_bar_id, :bar_producto_id],
              unique: true, name: 'index_provisiones_evento_producto'
    remove_column :evento_bar_provisiones, :provisionable_type
    remove_column :evento_bar_provisiones, :provisionable_id
  end
end
