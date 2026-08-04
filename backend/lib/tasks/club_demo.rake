namespace :club do
  # Genera el CLUB MODELO: un club lleno de datos inventados en todos los módulos, para mostrarle la
  # app a alguien que no la conoce. Ver `Clubs::SembrarDemo`.
  #
  #   rake club:demo
  #   rake club:demo NOMBRE="Club Modelo" SLUG=club_modelo PACIENTES=40 DISPENSACIONES=200 LOTES=30
  #   rake club:demo REGENERAR=1     # borra el anterior y lo vuelve a crear
  #
  # Es reproducible: misma semilla, mismo club. Si algo se ve raro en una demo, se puede repetir.
  task demo: :environment do
    slug = (ENV['SLUG'].presence || 'club_modelo').downcase.gsub(/[^a-z0-9_]/, '_')

    if ENV['REGENERAR'].present?
      existente = ActsAsTenant.without_tenant { Club.unscoped.find_by(slug: slug) }
      if existente
        unless existente.demo?
          abort "El club '#{slug}' NO está marcado como demo: no se borra. " \
                'Si de verdad querés eliminarlo, hacelo a mano.'
        end
        puts "Borrando el club demo anterior (##{existente.id})…"
        Clubs::BorrarDemo.call(club: existente)
      end
    end

    password = ENV['PASSWORD'].presence
    res = Clubs::SembrarDemo.call(
      nombre: ENV['NOMBRE'].presence || 'Club Modelo',
      slug: slug,
      admin_email: ENV['ADMIN_EMAIL'],
      admin_password: password,
      pacientes:      (ENV['PACIENTES'] || 40).to_i,
      dispensaciones: (ENV['DISPENSACIONES'] || 200).to_i,
      lotes:          (ENV['LOTES'] || 30).to_i,
    )

    puts "\n✓ Club ##{res.club.id} «#{res.club.name}» (slug: #{res.club.slug}) — marcado como DEMO"
    res.resumen.sort_by { |_, v| -v }.each { |k, v| puts format('  %-24s %6d', k, v) }
    puts "\n  Entrá con cualquiera de estos (misma contraseña):"
    res.club.users.order(:role).each { |u| puts "    #{u.role.ljust(12)} #{u.email}" }
    puts "  Password: #{res.password}"
  end
end
