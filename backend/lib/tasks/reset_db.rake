# lib/tasks/reset_db.rake
namespace :db do
  desc "Borra TODOS los datos y deja solo los super_admin. Uso: CONFIRM_RESET=SI rails db:reset_keep_superadmins"
  task reset_keep_superadmins: :environment do
    abort "Abortado: seteá CONFIRM_RESET=SI para confirmar." unless ENV["CONFIRM_RESET"] == "SI"

    conn = ActiveRecord::Base.connection

    super_admins = User.where(role: "super_admin").map { |u| u.attributes.merge("club_id" => nil) }
    abort "Abortado: no hay super_admins, te quedarías sin acceso al sistema." if super_admins.empty?

    tables = conn.tables - %w[schema_migrations ar_internal_metadata]
    conn.execute("TRUNCATE TABLE #{tables.map { |t| conn.quote_table_name(t) }.join(", ")} RESTART IDENTITY CASCADE")

    User.insert_all(super_admins)
    conn.execute("SELECT setval(pg_get_serial_sequence('users', 'id'), COALESCE((SELECT MAX(id) FROM users), 0) + 1, false)")

    puts "Listo. super_admins: #{User.where(role: "super_admin").count}. Resto: vacío."
  end
end