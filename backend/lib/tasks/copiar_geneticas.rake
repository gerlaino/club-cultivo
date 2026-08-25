# Copia el catálogo de genéticas de una organización a otra.
#
# El caso que lo motivó: las variedades se cargaron en Mitocondria_TEST y hay que llevarlas al
# Mitocondria real, que es donde se va a dispensar. `rake migrar_club` no sirve para esto: MUEVE
# todo a un destino vacío, y acá hay que COPIAR una sola tabla a una organización que ya opera.
#
# Uso:
#   bundle exec rake geneticas:copiar ORIGEN=12 DESTINO=42 SIMULAR=1
#   bundle exec rake geneticas:copiar ORIGEN=12 DESTINO=42
#
# Sin DESTINO apunta al Mitocondria MÁS NUEVO, igual que `pacientes:mitocondria`.
#
# Es idempotente: saltea por `slug` las que el destino ya tenga, así que se puede volver a
# correr después de cargar variedades nuevas en el origen.
#
# Lo que NO copia, a propósito:
#   · Las FOTOS (ActiveStorage). Se copian aparte si hacen falta.
#   · `numero_registro_inase` / `fecha_registro_inase`: el número tiene un índice ÚNICO GLOBAL
#     (`idx_geneticas_numero_inase`), así que duplicarlo revienta el INSERT. Y no hace falta: el
#     número vive en el catálogo GLOBAL del INASE y una genética del club se ata a él con
#     `declarada_como_id`, que sí viaja porque apunta a un registro compartido por todos.
namespace :geneticas do
  desc 'Copia las genéticas de una organización a otra (ORIGEN=, DESTINO=, SIMULAR=1)'
  task copiar: :environment do
    simular = ENV['SIMULAR'].present?

    abort('Falta ORIGEN=<club_id>. Mirá los ids con: Club.where("name ILIKE \'%mitocondria%\'")') if ENV['ORIGEN'].blank?

    origen, destino = ActsAsTenant.without_tenant do
      o = Club.find(ENV['ORIGEN'])
      d = if ENV['DESTINO'].present?
        Club.find(ENV['DESTINO'])
      else
        Club.where('name ILIKE ?', '%Mitocondria%').where.not(id: o.id).order(created_at: :desc).first
      end
      [o, d]
    end
    abort('No encontré el destino. Pasá DESTINO=<club_id>.') if destino.nil?
    abort('Origen y destino son la misma organización.') if origen.id == destino.id

    puts "Origen  : ##{origen.id} #{origen.name}"
    puts "Destino : ##{destino.id} #{destino.name}  (creada #{destino.created_at.to_date})"
    puts "Modo    : #{simular ? 'SIMULACRO (no escribe)' : 'REAL'}"
    puts '-' * 74

    copiar, existen, errores = [], [], []

    fuente = ActsAsTenant.without_tenant do
      Genetica.unscoped.where(club_id: origen.id, deleted_at: nil).order(:nombre).to_a
    end
    abort("La organización ##{origen.id} no tiene genéticas propias.") if fuente.empty?

    ActsAsTenant.with_tenant(destino) do
      fuente.each do |g|
        # El índice único es (club_id, slug) y NO filtra borradas: el guard tiene que mirar
        # todas, o el save choca contra el índice con una soft-deleted del destino.
        ya = Genetica.unscoped.where(club_id: destino.id, slug: g.slug).exists?
        if ya
          existen << "#{g.nombre} (#{g.slug})"
          next
        end

        copia = Genetica.new(
          club:                     destino,
          nombre:                   g.nombre,
          descripcion:              g.descripcion,
          thc:                      g.thc,
          cbd:                      g.cbd,
          tipo:                     g.tipo,
          origen:                   g.origen,
          criador:                  g.criador,
          terpenos:                 g.terpenos,
          tiempo_floracion:         g.tiempo_floracion,
          rendimiento:              g.rendimiento,
          altura:                   g.altura,
          dificultad:               g.dificultad,
          dias_vegetativo_objetivo: g.dias_vegetativo_objetivo,
          dias_cosecha_objetivo:    g.dias_cosecha_objetivo,
          consejos_club:            g.consejos_club,
          categoria_inase:          g.categoria_inase,
          activa:                   g.activa,
          disponible:               g.disponible,
          visible_paciente:         g.visible_paciente,
          global:                   false,
          registrada_inase:         false,
          # Sólo si apunta al catálogo GLOBAL, que es el único compartido entre organizaciones.
          declarada_como_id:        (g.declarada_como_id if g.declarada_como&.club_id.nil?),
        )
        copia.slug = g.slug

        copia.valid? ? copiar << [g, copia] : errores << "#{g.nombre}: #{copia.errors.full_messages.join(' · ')}"
      end

      unless simular || copiar.empty?
        ActiveRecord::Base.transaction { copiar.each { |_g, c| c.save! } }
      end
    end

    puts "#{simular ? 'A copiar' : 'Copiadas'} : #{copiar.size}"
    copiar.each do |g, _c|
      decl = g.declarada_como ? "  → declara como #{g.declarada_como.nombre}" : ''
      puts format('   %-34s %s%s', g.nombre, g.tipo || '—', decl)
    end

    if existen.any?
      puts "\nYa estaban en el destino (salteadas): #{existen.size}"
      existen.each { |e| puts "   #{e}" }
    end

    if errores.any?
      puts "\nCon error (NO se copian): #{errores.size}"
      errores.each { |e| puts "   #{e}" }
    end

    con_foto = ActsAsTenant.without_tenant do
      ActiveStorage::Attachment.where(record_type: 'Genetica', record_id: fuente.map(&:id)).count
    end

    puts '-' * 74
    puts "Ojo: #{con_foto} foto(s) adjuntas en el origen que este task NO copia." if con_foto.positive?
    if simular
      puts 'Simulacro: no se escribió nada. Sacá SIMULAR=1 para aplicar.'
    else
      puts "Listo. #{copiar.size} genéticas en #{destino.name}."
    end
  end
end
