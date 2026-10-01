namespace :manicura do
  # Qué pudo quedar mal en los datos por los agujeros del pesaje que se cerraron el 1-oct-2026
  # (ver `Manicura::Diagnostico`). SÓLO LEE, salvo las plantas trabadas, que se corrigen con
  # CORREGIR_TRABADAS=1 (vuelven a quedar sin pesar, como al borrar su jornada).
  #
  #   rake manicura:diagnostico                       # lista todo
  #   CLUB_ID=3 rake manicura:diagnostico             # una organización
  #   rake manicura:diagnostico CORREGIR_TRABADAS=1   # además destraba las plantas trabadas
  #   rake manicura:diagnostico CORREGIR_AGOTADOS=1   # además reabre los frascos agotados con producto
  desc 'Lista lo que pudo quedar mal en los pesajes de manicura (sólo lee)'
  task diagnostico: :environment do
    ActsAsTenant.without_tenant do
      clubs = ENV['CLUB_ID'].present? ? [ENV['CLUB_ID'].to_i] : nil
      diag  = Manicura::Diagnostico.new(club_ids: clubs)
      r     = diag.call
      titulos = {
        doble_pesada:     'Plantas pesadas en dos jornadas (si las dos se confirmaron, su peso entró dos veces al stock)',
        trabadas:         'Plantas trabadas: con peso y sin pesada en un lote en manicura (el lote no puede cerrar)',
        rendimiento:      'Lotes cerrados cuyo rendimiento no es la suma de sus pesajes confirmados',
        agotado_con_peso: 'Frascos marcados agotados que tienen producto (la lista de stock los esconde)',
        no_es_flor:       'Pesajes confirmados en un frasco que no es de flor seca',
      }
      titulos.each do |clave, titulo|
        filas = r.public_send(clave)
        puts "\n== #{titulo}: #{filas.size}"
        filas.each { |f| puts "   #{f.map { |k, v| "#{k}=#{v.is_a?(Array) ? v.join(' / ') : v}" }.join(' · ')}" }
      end
      puts(r.vacio? ? "\n✓ No hay nada para revisar." : "\nRevisalo antes de tocar nada: nada de esto se corrige solo.")
      if ENV['CORREGIR_TRABADAS'].present? && r.trabadas.any?
        puts "✓ #{diag.corregir_trabadas!} plantas trabadas volvieron a quedar sin pesar."
      end
      if ENV['CORREGIR_AGOTADOS'].present? && r.agotado_con_peso.any?
        puts "✓ #{diag.corregir_agotados!} frascos agotados con producto se reabrieron."
      end
    end
  end
end
