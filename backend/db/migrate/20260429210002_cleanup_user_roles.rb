class CleanupUserRoles < ActiveRecord::Migration[7.2]
  def up
    execute "UPDATE users SET role = 'admin'   WHERE role = 'tesorero'"
    execute "UPDATE users SET role = 'manicura' WHERE role = 'manicurador'"
  end

  def down
    execute "UPDATE users SET role = 'manicurador' WHERE role = 'manicura'"
    # tesorero→admin is intentionally non-reversible
  end
end
