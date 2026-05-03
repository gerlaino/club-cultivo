class AddEstadoToStocksAndMakeSedeNullable < ActiveRecord::Migration[7.2]
  def up
    # Make sede_id nullable (stock can be unassigned, "pool del club")
    change_column_null :stocks, :sede_id, true

    # Add estado field: pendiente_asignacion | asignado | agotado
    add_column :stocks, :estado, :string, null: false, default: 'asignado'
    add_index  :stocks, :estado

    # Existing records are already assigned to a sede → mark as 'asignado'
    execute "UPDATE stocks SET estado = 'asignado' WHERE estado IS NULL OR estado = ''"
  end

  def down
    remove_index  :stocks, :estado
    remove_column :stocks, :estado

    # Revert sede_id to NOT NULL (set a fallback for any null values before reverting)
    change_column_null :stocks, :sede_id, false
  end
end
