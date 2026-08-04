namespace :alertas do
  # Borra las alertas de `maceta_chica`, que quedaron huérfanas al eliminarse esa alerta. Sin esto
  # siguen apareciendo en el panel hasta que alguien las marque leídas una por una, avisando de algo
  # que la app ya no calcula.
  #
  #   rake alertas:limpiar_maceta            # muestra cuántas hay, NO borra
  #   rake alertas:limpiar_maceta CONFIRMAR=1  # borra
  #
  # Pide confirmación explícita a propósito: borra datos y no se puede deshacer.
  task limpiar_maceta: :environment do
    ActsAsTenant.without_tenant do
      scope = AlertaInterna.unscoped.where(tipo: 'maceta_chica')
      total = scope.count

      if total.zero?
        puts 'No hay alertas de maceta_chica: nada que hacer.'
        next
      end

      por_club = scope.group(:club_id).count
      puts "Se encontraron #{total} alertas de 'maceta_chica':"
      por_club.sort_by { |_, v| -v }.each do |club_id, n|
        nombre = Club.unscoped.find_by(id: club_id)&.name || '(club borrado)'
        puts format('  %-30s %5d', nombre, n)
      end

      if ENV['CONFIRMAR'].blank?
        puts "\nNo se borró nada. Para borrarlas: rake alertas:limpiar_maceta CONFIRMAR=1"
        next
      end

      borradas = scope.delete_all
      puts "\n✓ #{borradas} alertas borradas."
    end
  end
end
