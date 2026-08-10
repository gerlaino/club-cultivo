namespace :geneticas do
  # Qué le falta declarar a cada club. Una genética que no está inscripta en el INASE y
  # tampoco declara contra una que lo esté no se puede acreditar ante el organismo: el
  # informe la muestra como pendiente y esta tarea la lista sin tener que entrar club por club.
  #
  #   bundle exec rake geneticas:sin_declarar
  # Antes de que existiera el vínculo, los clubes declaraban a mano METIENDO EL PAR EN EL
  # NOMBRE: "Blue Sherbet - Tropicana WFC". Eso ya es la declaración, sólo que escrita donde
  # la app no la puede leer. Esta tarea la reconoce y la convierte en vínculo de verdad.
  #
  # También limpia el sufijo del nombre: el par pasa a vivir en `declarada_como_id`, así que
  # repetirlo en el nombre es ruido — y en las pantallas internas el cultivador quiere leer
  # "Blue Sherbet". Si el nombre limpio chocara con otra genética del mismo club, se vincula
  # igual pero NO se renombra (y se avisa): perder un nombre distinto es peor que un sufijo.
  #
  #   bundle exec rake geneticas:declarar_por_nombre SIMULAR=1
  #   bundle exec rake geneticas:declarar_por_nombre
  #   bundle exec rake geneticas:declarar_por_nombre CONSERVAR_NOMBRE=1   # vincula sin renombrar
  desc 'Vincula al INASE las genéticas que ya traen la variedad en el nombre ("X - TROPICANA WFC")'
  task declarar_por_nombre: :environment do
    simular   = ENV['SIMULAR'].present?
    conservar = ENV['CONSERVAR_NOMBRE'].present?

    ActsAsTenant.without_tenant do
      inscriptas = Genetica.unscoped.where(club_id: nil, registrada_inase: true).to_a
      if inscriptas.empty?
        puts 'No hay variedades inscriptas en el catálogo: no hay contra qué declarar.'
        next
      end

      candidatas = Genetica.unscoped
                           .where.not(club_id: nil)
                           .where(registrada_inase: [false, nil], declarada_como_id: nil)
                           .order(:club_id, :nombre)

      vinculadas = 0
      renombradas = 0
      choques = []

      candidatas.each do |g|
        # El nombre de la variedad, al final del nombre, detrás de un separador.
        destino = inscriptas.find do |i|
          g.nombre.match?(/\s*[-–—·|]\s*#{Regexp.escape(i.nombre)}\s*\z/i)
        end
        next if destino.nil?

        limpio = g.nombre.sub(/\s*[-–—·|]\s*#{Regexp.escape(destino.nombre)}\s*\z/i, '').strip
        renombrar = !conservar && limpio.present? &&
                    !Genetica.unscoped.where(club_id: g.club_id, nombre: limpio)
                             .where.not(id: g.id).exists?

        if !conservar && limpio.present? && !renombrar
          choques << "#{g.nombre} (ya existe «#{limpio}» en el club)"
        end

        etiqueta = renombrar ? "#{g.nombre}  →  «#{limpio}» declarada como #{destino.nombre}"
                             : "#{g.nombre}  →  declarada como #{destino.nombre} (nombre sin tocar)"
        puts "  #{simular ? '[simulado] ' : ''}#{etiqueta}"
        next if simular

        attrs = { declarada_como_id: destino.id }
        attrs[:nombre] = limpio if renombrar
        # update_columns: no se toca el slug, para no romper los links de la web pública que
        # ya estén circulando.
        g.update_columns(attrs)
        vinculadas += 1
        renombradas += 1 if renombrar
      end

      if vinculadas.zero? && !simular
        puts 'Ninguna genética trae la variedad INASE en el nombre.'
      elsif !simular
        puts "\nListo: #{vinculadas} declarada(s), #{renombradas} renombrada(s)."
      else
        puts "\nSIMULACIÓN: no se cambió nada."
      end

      if choques.any?
        puts "\nSin renombrar por choque de nombre (quedaron declaradas igual):"
        choques.each { |c| puts "  #{c}" }
      end
    end
  end

  desc 'Lista las genéticas que no están inscriptas ni declaradas contra una del INASE'
  task sin_declarar: :environment do
    ActsAsTenant.without_tenant do
      pendientes = Genetica.unscoped
                           .where.not(club_id: nil)
                           .where(registrada_inase: [false, nil], declarada_como_id: nil)
                           .order(:club_id, :nombre)

      if pendientes.empty?
        puts 'Todas las genéticas están inscriptas o declaradas.'
        next
      end

      pendientes.group_by(&:club_id).each do |club_id, gs|
        club = Club.unscoped.find_by(id: club_id)
        puts "\n#{club&.name || "club ##{club_id}"} — #{gs.size} sin declarar"
        gs.each do |g|
          lotes = Lote.unscoped.where(genetica_id: g.id).count
          puts "  #{g.nombre}#{lotes.positive? ? " (#{lotes} lote#{'s' if lotes != 1})" : ' (sin lotes)'}"
        end
      end

      puts "\nSe declaran desde la ficha de cada genética: campo \"Se declara ante el INASE como\"."
    end
  end
end

namespace :lotes do
  # Un lote 'finalizado' que todavía tiene stock (o derivados) es un estado imposible: el
  # informe de trazabilidad lo muestra como ciclo cerrado con cientos de gramos adentro.
  #
  # Los generó `Clubs::SembrarDemo`, que elegía el estado por antigüedad y después le sorteaba
  # el gramaje restante, sin cruzarlos. La regla real (`Lote#finalizar_si_stock_agotado!`)
  # nunca estuvo mal: lo que faltaba era que nadie pudiera escribir el estado por afuera.
  #
  #   bundle exec rake lotes:corregir_finalizados_con_stock
  #   bundle exec rake lotes:corregir_finalizados_con_stock SIMULAR=1
  desc 'Devuelve a "curado" los lotes finalizados que todavía tienen stock o derivados'
  task corregir_finalizados_con_stock: :environment do
    simular = ENV['SIMULAR'].present?

    ActsAsTenant.without_tenant do
      afectados = Lote.unscoped.where(estado: 'finalizado').select do |lote|
        Stock.unscoped.where(lote_id: lote.id, deleted_at: nil)
             .where.not(estado: 'agotado').where('cantidad > 0').exists?
      end

      if afectados.empty?
        puts 'Nada que corregir: no hay lotes finalizados con stock.'
        next
      end

      puts "Lotes finalizados que todavía tienen producto: #{afectados.size}"
      afectados.each do |lote|
        resto = Stock.unscoped.where(lote_id: lote.id, deleted_at: nil)
                     .where.not(estado: 'agotado').sum(:cantidad)
        puts "  #{simular ? '[simulado] ' : ''}#{lote.codigo} (club #{lote.club_id}) — quedan #{resto.to_f.round(1)}"
        next if simular

        lote.update_columns(estado: 'curado')
        # El evento miente sobre la línea de tiempo y de ahí salen los días por fase.
        LoteEvento.unscoped.where(lote_id: lote.id, tipo: 'cambio_estado', estado_nuevo: 'finalizado')
                  .delete_all
      end

      puts simular ? "\nSIMULACIÓN: no se cambió nada." : "\nListo: #{afectados.size} lote(s) devueltos a 'curado'."
    end
  end
end

namespace :suites do
  # El add-on `iot` NUNCA existió como bandera vieja: ni `add_features_to_clubs` ni
  # `migrar_features_a_suites` lo escriben. O sea que hoy, en producción, ningún club lo tiene
  # prendido salvo que alguien haya ido al panel del super admin a tildarlo.
  #
  # Desde que la ingesta de lecturas exige el módulo (Webhooks::LecturasController), un club
  # con hardware andando y el flag apagado deja de recibir datos EN SILENCIO: el sensor postea,
  # le responden 403 y nadie se entera hasta que alguien mira el gráfico y está plano.
  #
  # Esta tarea cierra ese hueco: si el club tiene dispositivos cargados, ya estaba usando IoT.
  # Es idempotente — se puede correr las veces que haga falta.
  #
  #   bundle exec rake suites:prender_iot_con_dispositivos
  #   bundle exec rake suites:prender_iot_con_dispositivos SIMULAR=1   # sólo muestra
  #
  # CORRERLA JUNTO CON EL DEPLOY, no después.
  desc 'Prende el add-on IoT a los clubes que ya tienen dispositivos cargados'
  task prender_iot_con_dispositivos: :environment do
    simular = ENV['SIMULAR'].present?

    ActsAsTenant.without_tenant do
      # Dispositivo es soft-delete: con `unscoped` entrarían los dados de baja y un club que
      # ya se sacó todos los sensores se llevaría el módulo de regalo. Se usa el scope normal.
      con_hardware = Club.unscoped.where(id: Dispositivo.select(:club_id).distinct)
      candidatos   = con_hardware.reject { |club| club.features['iot'] == true }

      if candidatos.empty?
        puts 'Nada que hacer: todos los clubes con dispositivos ya tienen IoT prendido.'
        next
      end

      puts "Clubes con dispositivos y IoT apagado: #{candidatos.size}"
      candidatos.each do |club|
        cantidad = Dispositivo.where(club_id: club.id).count
        puts "  #{simular ? '[simulado] ' : ''}##{club.id} #{club.name} — #{cantidad} dispositivo(s)"
        club.update_columns(features: club.features.merge('iot' => true)) unless simular
      end

      puts simular ? "\nSIMULACIÓN: no se cambió nada." : "\nListo: #{candidatos.size} club(es) actualizados."
    end
  end
end

namespace :dispensaciones do
  # Arrastre del placeholder 'mixto'.
  #
  # Hasta el fix, tanto la creación de dispensaciones como la entrega de reservas nacían con
  # `medio_pago: 'mixto'` "que los cobros afinan". En contra entrega no hay cobros al crear
  # —los hace el delivery después— así que el placeholder quedaba como valor final: toda
  # entrega a domicilio figuraba como pago mixto sin haberse pagado de dos formas.
  #
  # Esta tarea recalcula esos registros a partir de sus COBROS REALES, con el mismo criterio
  # que `afinar_medio_pago!`: un solo medio → ese medio; dos o más distintos → mixto de verdad;
  # sin cobros → no se toca (no hay información para decidir, y adivinar sería peor).
  #
  #   bundle exec rake dispensaciones:recalcular_medio_pago SIMULAR=1
  #   bundle exec rake dispensaciones:recalcular_medio_pago
  desc 'Recalcula el medio de pago de las dispensaciones marcadas "mixto" sin serlo'
  task recalcular_medio_pago: :environment do
    simular = ENV['SIMULAR'].present?

    ActsAsTenant.without_tenant do
      candidatas = Dispensacion.unscoped.where(medio_pago: 'mixto')
      corregidas = 0
      sin_datos  = 0

      candidatas.find_each do |d|
        medios = d.cobros.pluck(:medio).uniq

        if medios.empty?
          # Sin cobros no se puede deducir nada. Si es contra entrega y todavía no se cobró,
          # 'efectivo' es lo que asume el alta nueva; si no, se deja como está y se cuenta.
          if d.cobrar_en_entrega?
            puts "  #{simular ? '[simulado] ' : ''}##{d.id} contra entrega sin cobrar → efectivo"
            d.update_columns(medio_pago: 'efectivo') unless simular
            corregidas += 1
          else
            sin_datos += 1
          end
          next
        end

        next if medios.size > 1   # mixto de verdad: dos medios distintos

        puts "  #{simular ? '[simulado] ' : ''}##{d.id} → #{medios.first}"
        d.update_columns(medio_pago: medios.first) unless simular
        corregidas += 1
      end

      puts "\nMarcadas 'mixto': #{candidatas.count}"
      puts "Corregidas: #{corregidas}#{simular ? ' (simulado)' : ''}"
      puts "Sin cobros y sin contra entrega (se dejan como están): #{sin_datos}" if sin_datos.positive?
    end
  end
end
