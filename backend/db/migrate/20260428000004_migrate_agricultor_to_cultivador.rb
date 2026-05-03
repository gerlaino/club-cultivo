class MigrateAgricultorToCultivador < ActiveRecord::Migration[7.2]
  def up
    execute "UPDATE users SET role = 'cultivador' WHERE role = 'agricultor'"
  end

  def down
    # Irreversible by design — agricultor role is removed from the system
    raise ActiveRecord::IrreversibleMigration
  end
end
