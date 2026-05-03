class AddDeletedAtToSalasLotesSedes < ActiveRecord::Migration[7.1]
  def up
    add_column :salas,  :deleted_at, :datetime
    add_column :lotes,  :deleted_at, :datetime
    add_column :sedes,  :deleted_at, :datetime
    add_index  :salas,  :deleted_at
    add_index  :lotes,  :deleted_at
    add_index  :sedes,  :deleted_at
  end

  def down
    remove_index  :salas,  :deleted_at
    remove_index  :lotes,  :deleted_at
    remove_index  :sedes,  :deleted_at
    remove_column :salas,  :deleted_at
    remove_column :lotes,  :deleted_at
    remove_column :sedes,  :deleted_at
  end
end
