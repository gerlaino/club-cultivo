namespace :cc do
  desc "Reset production DB: truncate everything, create 2 super_admins only"
  task reset_prod: :environment do
    abort "Solo para uso en producción. Exportá FORCE_PROD_RESET=1 para confirmar." unless ENV["FORCE_PROD_RESET"] == "1"

    puts "🗑  Truncando todas las tablas..."

    conn = ActiveRecord::Base.connection

    # Orden inverso de dependencias para evitar FK violations
    tables = %w[
      pesadas_plantas pesadas stocks dispensaciones
      plant_activities plants lotes
      socio_notas indicacion_medicas socios
      salas sedes geneticas cepas
      costo_lotes movimientos_contables
      users clubs
      ar_internal_metadata
    ]

    conn.execute("SET session_replication_role = replica") rescue nil
    tables.each do |t|
      conn.execute("TRUNCATE TABLE #{t} CASCADE") rescue puts "  (skip) #{t}"
    end
    conn.execute("SET session_replication_role = DEFAULT") rescue nil

    puts "✅ Tablas vaciadas\n\n"

    tmp_pass = "ChangeMe#{rand(1000..9999)}!"

    super1 = User.new(
      email:                 "german.laino@gmail.com",
      password:              tmp_pass,
      password_confirmation: tmp_pass,
      role:                  "super_admin",
      first_name:            "German",
      last_name:             "Laino",
    )
    super1.save!(validate: false)
    puts "👤 #{super1.email}"

    super2 = User.new(
      email:                 "superadmin@cultivoespacial.app",
      password:              tmp_pass,
      password_confirmation: tmp_pass,
      role:                  "super_admin",
      first_name:            "Super",
      last_name:             "Admin",
    )
    super2.save!(validate: false)
    puts "👤 #{super2.email}"

    puts "\n✅ RESET COMPLETO"
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts "  Email 1 : german.laino@gmail.com"
    puts "  Email 2 : superadmin@cultivoespacial.app"
    puts "  Password: #{tmp_pass}  ← cambiala al loguearte"
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  end
end
