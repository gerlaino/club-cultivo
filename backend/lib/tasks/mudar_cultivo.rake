# Muda el cultivo ACTIVO de una organización a otra, conservando los QR.
#
# El caso: se probó en Mitocondria_TEST, se cargaron lotes con plantas y se imprimieron las
# etiquetas. Ahora hay que llevarlos al Mitocondria real sin reimprimir nada.
#
# ⚠️ ES UNA MUDANZA, NO UNA COPIA, y no puede ser otra cosa: `codigo_qr` es único GLOBAL en
# lotes, plantas y stocks. Copiar exigiría regenerar los códigos, y eso invalida cada etiqueta
# ya pegada — que es justo lo que se quiere conservar. Se cambia el dueño, no se duplica.
#
# QUÉ SE MUEVE: los lotes en `Lote::CULTIVO_ESTADOS` —enraizado, vegetativo, floración— con sus
# plantas. No es "todo menos finalizado": de cosecha en adelante empieza a haber pesajes y stock,
# y esos se quedan donde están. Esa lista ya existe en el modelo y es la misma que exige sala, así
# que los lotes que se mudan son exactamente los que necesitan una sala en destino.
#
# LAS SALAS SE COPIAN, no se mudan. No tienen unicidad global, así que duplicarlas es seguro; y
# mudarlas dejaría a los lotes finalizados que se quedan apuntando a una sala de otra
# organización, que es el cruce que esto viene a evitar.
#
# Uso:
#   bundle exec rake cultivo:mudar ORIGEN=3 DESTINO=14 SEDE_DESTINO=<id> SIMULAR=1
#   bundle exec rake cultivo:mudar ORIGEN=3 DESTINO=14 SEDE_DESTINO=<id>
#
# Corré el backup ANTES: `rake backup:create`.
namespace :cultivo do
  desc 'Muda los lotes activos y sus plantas de una organización a otra (SIMULAR=1 para reportar)'
  task mudar: :environment do
    simular = ENV['SIMULAR'].present?

    abort('Falta ORIGEN=<club_id>.')  if ENV['ORIGEN'].blank?
    abort('Falta DESTINO=<club_id>.') if ENV['DESTINO'].blank?

    ActsAsTenant.without_tenant do
      origen  = Club.find(ENV['ORIGEN'])
      destino = Club.find(ENV['DESTINO'])
      abort('Origen y destino son la misma organización.') if origen.id == destino.id

      sede = if ENV['SEDE_DESTINO'].present?
        destino.sedes.find(ENV['SEDE_DESTINO'])
      else
        destino.sedes.activas.where(tipo: %w[produccion mixta]).order(:id).first
      end
      abort("La organización ##{destino.id} no tiene una sede que admita cultivo. Pasá SEDE_DESTINO=<id>.") if sede.nil?

      lotes = Lote.unscoped.where(club_id: origen.id, deleted_at: nil, estado: Lote::CULTIVO_ESTADOS)
                  .order(:codigo).to_a
      abort('No hay lotes activos para mudar.') if lotes.empty?

      lote_ids  = lotes.map(&:id)
      plantas   = Plant.unscoped.where(lote_id: lote_ids, deleted_at: nil)
      planta_ids = plantas.pluck(:id)

      puts "Origen  : ##{origen.id} #{origen.name}"
      puts "Destino : ##{destino.id} #{destino.name} — sede #{sede.nombre}"
      puts "Modo    : #{simular ? 'SIMULACRO (no escribe)' : 'REAL'}"
      puts '-' * 74

      # ── Frenos: mejor no mudar que mudar a medias ───────────────────────────
      problemas = []

      con_stock = Stock.unscoped.where(lote_id: lote_ids, deleted_at: nil).count
      problemas << "#{con_stock} stock(s) cuelgan de lotes activos: se quedarían apuntando a otra organización." if con_stock.positive?

      sin_gen = lotes.count { |l| l.genetica_id.nil? }
      problemas << "#{sin_gen} lote(s) sin genética." if sin_gen.positive?

      # Cada genética tiene que existir en destino con el mismo slug. Es la suposición sobre la
      # que se apoya todo el re-apuntado: sin la copia, el lote aterriza sin genética.
      mapa_gen = {}
      lotes.map(&:genetica_id).compact.uniq.each do |gid|
        slug = Genetica.unscoped.find_by(id: gid)&.slug
        copia = slug && Genetica.unscoped.find_by(club_id: destino.id, slug: slug, deleted_at: nil)
        if copia
          mapa_gen[gid] = copia.id
        elsif slug && Genetica.unscoped.exists?(club_id: destino.id, slug: slug)
          # La copia existe pero está BORRADA. `geneticas:copiar` la saltea —el índice único de
          # (club_id, slug) no filtra borradas, así que crear otra explota— y acá no sirve para
          # re-apuntar. Hay que restaurarla a mano: el mensaje genérico mandaría a buscar una
          # copia que sí está, sólo que eliminada.
          nombre = Genetica.unscoped.find_by(id: gid)&.nombre
          problemas << "La genética \"#{nombre}\" existe en el destino pero está ELIMINADA (slug #{slug.inspect}): restaurala antes de mudar."
        else
          problemas << "La genética ##{gid} no tiene copia en el destino (slug #{slug.inspect}): corré primero `rake geneticas:copiar`."
        end
      end

      if problemas.any?
        puts 'NO SE PUEDE MUDAR TODAVÍA:'
        problemas.each { |p| puts "   · #{p}" }
        abort('Resolvé eso primero.')
      end

      # ── Salas: se copian, reusando la que ya exista con ese nombre ──────────
      salas_origen = Sala.unscoped.where(id: lotes.map(&:sala_id).compact.uniq).order(:nombre).to_a
      mapa_sala    = {}
      salas_nuevas = []

      salas_origen.each do |sa|
        ya = Sala.unscoped.find_by(club_id: destino.id, sede_id: sede.id, nombre: sa.nombre, deleted_at: nil)
        if ya
          # Reusar sólo si es del mismo tipo: meter un lote de floración en una sala de
          # vegetativo lo deja en una combinación que el modelo rechaza.
          abort("En el destino ya hay una sala \"#{sa.nombre}\" pero es #{ya.kind} y la de origen es #{sa.kind}.") if ya.kind != sa.kind
          mapa_sala[sa.id] = ya.id
        else
          copia = Sala.new(club_id: destino.id, sede_id: sede.id, nombre: sa.nombre, kind: sa.kind,
                           tipo: sa.tipo, state: sa.state, pots_count: sa.pots_count,
                           plants_max: sa.plants_max, notes: sa.notes)
          salas_nuevas << [sa, copia]
        end
      end

      puts "Salas a copiar : #{salas_nuevas.size}#{" (#{mapa_sala.size} ya existían y se reusan)" if mapa_sala.any?}"
      salas_nuevas.each { |sa, _| puts "   #{sa.nombre} (#{sa.kind})" }

      puts "\nLotes a mudar  : #{lotes.size}"
      lotes.group_by(&:estado).each { |e, ls| puts "   #{e.ljust(12)} #{ls.size}" }
      puts "Plantas        : #{plantas.count} (#{plantas.where.not(codigo_qr: nil).count} con QR)"

      # Una planta madre que se queda en el origen dejaría el puntero cruzado entre
      # organizaciones. Se corta el vínculo: la planta sigue, su origen queda sin registrar.
      madres_fuera = plantas.where.not(planta_madre_id: nil).where.not(planta_madre_id: planta_ids).count
      puts "Plantas con madre que NO se muda (se les corta el vínculo): #{madres_fuera}" if madres_fuera.positive?

      if simular
        puts '-' * 74
        puts 'Simulacro: no se escribió nada. Sacá SIMULAR=1 para mudar.'
        next
      end

      ActiveRecord::Base.transaction do
        salas_nuevas.each { |sa, copia| copia.save!; mapa_sala[sa.id] = copia.id }

        lotes.each do |l|
          l.update_columns(
            club_id:      destino.id,
            sede_id:      sede.id,
            sala_id:      mapa_sala[l.sala_id],
            genetica_id:  mapa_gen[l.genetica_id],
            # Un usuario del origen: en destino no existe y el vínculo quedaría cruzado.
            manicurador_id: nil,
          )
        end

        # Las plantas y lo que lleva `club_id`. `update_all` a propósito: son cientos de filas y
        # acá no hay nada que validar — el dueño cambia, el dato es el mismo.
        Plant.unscoped.where(id: planta_ids).update_all(club_id: destino.id)
        Plant.unscoped.where(id: planta_ids).where.not(planta_madre_id: nil)
             .where.not(planta_madre_id: planta_ids).update_all(planta_madre_id: nil)

        LoteEvento.unscoped.where(lote_id: lote_ids).update_all(club_id: destino.id)
        RegistroAmbiental.unscoped.where(lote_id: lote_ids).update_all(club_id: destino.id)
        Nota.unscoped.where(noteable_type: 'Lote',  noteable_id: lote_ids).update_all(club_id: destino.id)
        Nota.unscoped.where(noteable_type: 'Plant', noteable_id: planta_ids).update_all(club_id: destino.id)

        # Lotes desprendidos de un lote que se queda: el vínculo cruzaría organizaciones.
        Lote.unscoped.where(id: lote_ids).where.not(lote_origen_id: nil)
            .where.not(lote_origen_id: lote_ids).update_all(lote_origen_id: nil)
        Lote.unscoped.where(id: lote_ids).where.not(planta_madre_id: nil)
            .where.not(planta_madre_id: planta_ids).update_all(planta_madre_id: nil)
      end

      puts '-' * 74
      puts "Listo. #{lotes.size} lotes y #{plantas.count} plantas en #{destino.name}, con sus QR intactos."
      puts "Verificá escaneando una etiqueta: tiene que resolver a la ficha dentro de #{destino.name}."
    end
  end
end
