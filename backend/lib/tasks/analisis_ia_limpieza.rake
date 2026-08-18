# Borra los análisis de lote guardados, que quedaron sin función.
#
# El "análisis de lote" devolvía un texto libre que se guardaba en `analisis_ia`, se leía una vez
# y no generaba nada: ni una tarea, ni una alerta, ni un cambio de setpoint. Pagaba la salida más
# cara de todas las funciones de IA para producir prosa sin destino. Lo reemplaza el chatbot del
# admin, que contesta sobre los datos de la organización y propone acciones concretas.
#
# La tabla `analisis_ia` NO se dropea acá: eso es una migración y va aparte. Este rake sólo vacía
# los datos, por organización, para poder mirar antes de borrar.
#
# Se borra en DURO (`delete_all`) a propósito: el modelo tenía soft-delete y estaba en la
# papelera. Un borrado blando dejaría las filas ahí para siempre, restaurables a una función que
# ya no existe.
namespace :analisis_ia do
  desc 'Borra los análisis de lote guardados (SIMULAR=1 para ver sin borrar; CLUB=id para uno solo)'
  task limpiar: :environment do
    simular = ENV['SIMULAR'].present?
    club_id = ENV['CLUB'].presence

    unless ActiveRecord::Base.connection.table_exists?('analisis_ia')
      puts 'La tabla `analisis_ia` ya no existe: nada que hacer.'
      next
    end

    scope = ActiveRecord::Base.connection.quote_table_name('analisis_ia')
    where = club_id ? " WHERE club_id = #{club_id.to_i}" : ''

    filas = ActiveRecord::Base.connection.select_all(
      "SELECT club_id, COUNT(*) AS n FROM #{scope}#{where} GROUP BY club_id ORDER BY club_id"
    ).to_a

    if filas.empty?
      puts 'No hay análisis guardados.'
      next
    end

    ActsAsTenant.without_tenant do
      filas.each do |f|
        nombre = Club.unscoped.find_by(id: f['club_id'])&.name || "club ##{f['club_id']}"
        puts "  #{simular ? '~' : '-'} #{nombre}: #{f['n']} análisis"
      end
    end

    total = filas.sum { |f| f['n'].to_i }

    if simular
      puts "\nSimulación: se borrarían #{total}."
    else
      ActiveRecord::Base.connection.execute("DELETE FROM #{scope}#{where}")
      puts "\nListo: #{total} borrados."
    end
  end
end
