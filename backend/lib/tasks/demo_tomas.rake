namespace :demo do
  # Deja el club demo de las GRABACIONES de la página pública («Mirá cómo se hace») listo para
  # grabar de nuevo. Cada toma crea cosas de verdad (una genética, un lote, un paciente, una
  # dispensa), así que antes de grabar se apartan las de la toma anterior —se renombran, no se
  # borran— y queda una paciente limpia para dispensar.
  #
  #   rake club:demo SLUG=asociacion_ejemplo NOMBRE="Asociación Ejemplo" PASSWORD=...   # una vez
  #   rake demo:preparar_tomas                                                          # antes de cada grabación
  #
  # Sólo toca un club marcado como demo. Lo llama `frontend/scripts/demos/grabar.mjs`.
  task preparar_tomas: :environment do
    slug = ENV['SLUG'].presence || 'asociacion_ejemplo'
    club = ActsAsTenant.without_tenant { Club.unscoped.find_by(slug: slug) }
    abort "No existe el club '#{slug}': crealo con rake club:demo SLUG=#{slug}" unless club
    abort "El club '#{slug}' no está marcado como demo: no se toca." unless club.demo?

    ActsAsTenant.with_tenant(club) do
      admin = User.find_by!(club_id: club.id, role: 'admin')
      # Cada toma suma pacientes: con el tope de 50 la grabación del alta termina en «el plan
      # permite hasta 50». La organización de ejemplo es la de 100.
      club.update_columns(plan: 'total') unless club.plan == 'total'
      sello = Time.current.strftime('%d%m %H%M%S')

      # Lo que crean las tomas, con nombres que no tienen que repetirse ni aparecer al buscar.
      Genetica.where(club_id: club.id, nombre: 'Gelato 41').find_each do |g|
        g.update_columns(nombre: "Toma #{sello} #{g.id}", slug: "toma-#{sello.tr(' ', '-')}-#{g.id}", disponible: false)
      end
      # El DNI también: la toma siguiente da de alta el mismo y la app rechaza el duplicado.
      Paciente.where(nombre: 'Lucía', apellido: 'Benedetti')
              .or(Paciente.where(nombre: 'Martina').where('apellido LIKE ?', 'Ríos%'))
              .or(Paciente.where(nombre: 'Toma').where.not('dni LIKE ?', '99%'))
              .update_all(["nombre = 'Toma', apellido = ?, dni = '99' || id, dni_normalizado = '99' || id", "Anterior #{sello}"])

      # La paciente a la que se le dispensa: activa, con REPROCANN vigente y sin deuda.
      Paciente.create!(
        club: club, created_by: admin, nombre: 'Martina', apellido: 'Ríos',
        dni: (30_000_000 + rand(9_000_000)).to_s, fecha_nacimiento: Time.zone.today - 34.years - 120.days,
        email: "martina.rios.#{Time.now.to_i}@example.com", telefono: '+54 11 5555-0101',
        reprocann_estado: 'activo', reprocann_vencimiento: Time.zone.today + 200,
        reprocann_numero: "RC-9#{rand(10_000..99_999)}",
      )
      # Un precio redondo para lo que se dispensa: el seed los sortea con centavos.
      Stock.where('descripcion LIKE ?', 'Amnesia Haze%').update_all(precio_sugerido_ars: 3200)
      puts "Listo para grabar: #{club.name} (##{club.id})"
    end

    demo_preparar_autocultivo!
  end

  # La cuenta de AUTOCULTIVO de las grabaciones: se crea como cualquier autoregistro (y queda
  # marcada demo, con el mail confirmado). Las carpas y sus plantas las arma con la app
  # `frontend/scripts/demos/base-autocultivo.mjs`. Acá se aparta lo que crea la toma de «Nueva
  # planta» (la genética «Gelato Auto» y sus plantas), para que la siguiente arranque igual.
  DEMO_AUTOCULTIVO_EMAIL = 'autocultivo@demo-video.example.com'.freeze

  def demo_preparar_autocultivo!
    usuario = ActsAsTenant.without_tenant { User.unscoped.find_by(email: DEMO_AUTOCULTIVO_EMAIL) }
    unless usuario
      registro = Registros::CrearPersonal.new(nombre: 'Sofía Paz', email: DEMO_AUTOCULTIVO_EMAIL,
                                              password: ENV['PASSWORD'].presence || 'DemoVideo2026!',
                                              acepta_terminos: true).call
      registro.club.update_columns(demo: true, plan_trial: false, plan_activo_hasta: nil)
      registro.update_columns(confirmado_at: Time.current)
      usuario = registro.user
    end
    club = usuario.club
    abort "La cuenta de autocultivo (#{club.id}) no está marcada como demo: no se toca." unless club.demo?

    ActsAsTenant.with_tenant(club) do
      sello = Time.current.strftime('%d%m %H%M%S')
      Genetica.where(club_id: club.id, nombre: 'Gelato Auto').find_each do |g|
        Lote.where(genetica_id: g.id).find_each do |lote|
          # `soft_delete!` y no `destroy`: `destroy` borra la fila y choca con las plantas.
          lote.plants.each(&:soft_delete!)
          lote.soft_delete!
        end
        g.update_columns(nombre: "Toma #{sello} #{g.id}", slug: "toma-#{sello.tr(' ', '-')}-#{g.id}", disponible: false)
      end
      puts "Listo para grabar: #{club.name} (##{club.id})"
    end
  end
end
