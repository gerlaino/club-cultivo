# Saca de `auditorias.cambios` lo que ya no se guarda pero quedó escrito de antes.
#
# `Dispensacion` no declaraba `auditar_solo`, así que el rastro se llevaba las 46 columnas —y,
# en cada entrega, una COPIA ENTERA de la firma en base64—. Eso volvía inútil la retención de
# imágenes: se borraba la firma de `dispensaciones` y quedaba la del rastro, para siempre, en la
# tabla que nadie mira. El modelo ya está arreglado; esto limpia lo viejo.
#
# NO borra filas: una auditoría es el registro de que algo pasó y eso se conserva. Lo que se
# saca son CLAVES de dentro del jsonb — la firma, los jsonb voluminosos y el token. Después de
# correrlo, la fila sigue diciendo quién hizo qué y cuándo.
namespace :auditorias do
  desc 'Saca firma/jsonb voluminosos de auditorias.cambios (SIMULAR=1 para ver sin tocar)'
  task limpiar_blobs: :environment do
    simular = ENV['SIMULAR'].present?
    claves  = %w[firma_entrega_data historial_envio producto_snapshot token]

    ActsAsTenant.without_tenant do
      alcance = Auditoria.where(auditable_type: 'Dispensacion')
                         .where(claves.map { |k| "cambios ? :#{k}" }.join(' OR '),
                                **claves.to_h { |k| [k.to_sym, k] })

      total = alcance.count
      if total.zero?
        puts 'Nada que limpiar: ninguna auditoría guarda esas claves.'
        next
      end

      pesa = ->(rel) { (rel.sum('length(cambios::text)').to_f / 1024).round(1) }
      antes = pesa.call(alcance)
      puts "#{total} auditoría(s) de Dispensación con esas claves — #{antes} KB en `cambios`."
      claves.each { |k| puts "  · #{k}: #{alcance.where('cambios ? :k', k: k).count}" }

      if simular
        puts "\nSIMULACIÓN: no se tocó nada. Corré sin SIMULAR=1 para aplicar."
        next
      end

      # `#-` sobre jsonb saca la clave. Se hace en una sola sentencia y sin instanciar modelos:
      # son filas de rastro, no hay callbacks que quieran correr sobre ellas.
      expresion = claves.inject('cambios') { |acc, k| "(#{acc} - '#{k}')" }
      afectadas = alcance.update_all("cambios = #{expresion}")

      despues = pesa.call(Auditoria.where(auditable_type: 'Dispensacion'))
      puts "\nListo: #{afectadas} fila(s) limpiadas. `cambios` de Dispensación quedó en #{despues} KB."
    end
  end
end
