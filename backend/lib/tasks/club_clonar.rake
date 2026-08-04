namespace :club do
  # Copia el CULTIVO de un club a uno nuevo (sedes, salas, genéticas, lotes, plantas e historia).
  # No lleva pacientes, contabilidad, dispensaciones ni tareas — ver `Clubs::Clonar`.
  #
  #   rake club:clonar CLUB_ORIGEN=3 NOMBRE="Mitocondria_TEST_2"
  #   rake club:clonar CLUB_ORIGEN=3 NOMBRE="Mitocondria_TEST_2" SLUG=mito-test-2 ADMIN_EMAIL=... PASSWORD=...
  #
  # Es todo o nada: si algo falla, la transacción vuelve atrás y no queda un club a medio copiar.
  task clonar: :environment do
    origen_id = ENV['CLUB_ORIGEN'].presence or abort 'Falta CLUB_ORIGEN=<id>'
    nombre    = ENV['NOMBRE'].presence      or abort 'Falta NOMBRE="Nombre del club nuevo"'

    origen = ActsAsTenant.without_tenant { Club.unscoped.find_by(id: origen_id) }
    abort "No existe el club #{origen_id}" unless origen

    password = ENV['PASSWORD'].presence || SecureRandom.hex(12)
    puts "Copiando el cultivo de «#{origen.name}» (##{origen.id}) a «#{nombre}»…"

    res = Clubs::Clonar.call(
      origen: origen, nombre: nombre, slug: ENV['SLUG'],
      admin_email: ENV['ADMIN_EMAIL'], admin_password: password,
    )

    puts "\n✓ Club ##{res.club.id} «#{res.club.name}» (slug: #{res.club.slug})"
    res.resumen.sort_by { |_, v| -v }.each { |k, v| puts format('  %-24s %6d', k, v) }
    puts "\n  Admin: #{res.club.users.first&.email}"
    puts "  Password: #{password}" if ENV['PASSWORD'].blank?
    puts "  (guardala: no se vuelve a mostrar)" if ENV['PASSWORD'].blank?
  end
end
