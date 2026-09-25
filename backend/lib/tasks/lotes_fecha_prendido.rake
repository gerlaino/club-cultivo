namespace :lotes do
  # Corrige la fecha de «pasó a vegetativo» de los lotes que prendieron con un trasplante cargado
  # con fecha pasada. Hasta el 24-sep-2026 el trasplante quedaba con su fecha, pero el cambio de
  # fase que dispara se grababa con el momento de la carga, y de ahí salen los días de ciclo, los
  # próximos pasos y los informes.
  #
  # Empareja cada cambio de fase «Prendió: pasó a maceta…» con el trasplante del mismo lote creado
  # en la misma operación (segundos de diferencia), y le copia su fecha. Si no encuentra
  # exactamente un trasplante, no toca ese lote y lo lista aparte para revisarlo a mano.
  #
  #   rake lotes:corregir_fecha_prendido              # muestra qué cambiaría, NO escribe
  #   rake lotes:corregir_fecha_prendido CONFIRMAR=1  # corrige
  #   CLUB_ID=3 rake lotes:corregir_fecha_prendido    # un solo club
  #
  # Idempotente: una segunda corrida no encuentra nada.
  desc 'Pone la fecha del trasplante en el cambio a vegetativo que ese trasplante disparó'
  task corregir_fecha_prendido: :environment do
    confirmar = ENV['CONFIRMAR'].present?
    ventana   = 10.seconds

    ActsAsTenant.without_tenant do
      prendidos = LoteEvento.unscoped.where(deleted_at: nil, tipo: 'cambio_estado',
                                            estado_anterior: 'enraizado', estado_nuevo: 'vegetativo')
                            .where('descripcion LIKE ?', 'Prendió: pasó a maceta%')
      prendidos = prendidos.where(club_id: ENV['CLUB_ID']) if ENV['CLUB_ID'].present?

      a_corregir = []
      dudosos    = []

      prendidos.includes(:lote).find_each do |prendido|
        trasplantes = LoteEvento.unscoped.where(deleted_at: nil, lote_id: prendido.lote_id,
                                                tipo: 'actividad', categoria: 'trasplante',
                                                created_at: (prendido.created_at - ventana)..(prendido.created_at + ventana))
                                .to_a
        # Sin trasplante al lado: la maceta se puso a mano desde la edición, y ahí la fecha de
        # carga ES la del prendido.
        next if trasplantes.empty?

        if trasplantes.size > 1
          dudosos << [prendido, "#{trasplantes.size} trasplantes en la misma operación"]
          next
        end

        trasplante = trasplantes.first
        next if trasplante.registrado_en == prendido.registrado_en

        a_corregir << [prendido, trasplante]
      end

      puts "Modo: #{confirmar ? 'CORRIGE' : 'SÓLO MUESTRA (no escribe)'}"
      puts '-' * 78
      if a_corregir.empty?
        puts 'No hay lotes con la fecha de vegetativo corrida.'
      else
        puts format('%-8s %-16s %-24s %-12s → %-12s', 'Club', 'Lote', 'Organización', 'Decía', 'Queda')
        a_corregir.each do |prendido, trasplante|
          lote = prendido.lote
          puts format('%-8s %-16s %-24s %-12s → %-12s',
                      prendido.club_id, lote&.codigo || "##{prendido.lote_id}",
                      Club.unscoped.find_by(id: prendido.club_id)&.name.to_s[0, 24],
                      prendido.registrado_en.strftime('%d/%m/%Y'), trasplante.registrado_en.strftime('%d/%m/%Y'))
        end
      end

      if dudosos.any?
        puts "\nPara revisar a mano (no se tocan):"
        dudosos.each { |p, motivo| puts "  lote ##{p.lote_id} (club #{p.club_id}): #{motivo}" }
      end

      puts '-' * 78
      unless confirmar
        puts "#{a_corregir.size} lote(s) a corregir. No se cambió nada. Para corregir: rake lotes:corregir_fecha_prendido CONFIRMAR=1" if a_corregir.any?
        next
      end

      LoteEvento.transaction do
        # update_columns: es corregir un dato, no un evento nuevo; no tiene que avisar ni auditar.
        a_corregir.each { |prendido, trasplante| prendido.update_columns(registrado_en: trasplante.registrado_en) }
      end
      puts "✓ #{a_corregir.size} lote(s) corregidos."
    end
  end
end
