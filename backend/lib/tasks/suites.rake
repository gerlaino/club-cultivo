namespace :geneticas do
  # Qué le falta declarar a cada club. Una genética que no está inscripta en el INASE y
  # tampoco declara contra una que lo esté no se puede acreditar ante el organismo: el
  # informe la muestra como pendiente y esta tarea la lista sin tener que entrar club por club.
  #
  #   bundle exec rake geneticas:sin_declarar
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
