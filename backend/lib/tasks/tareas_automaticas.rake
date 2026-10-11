# Las tareas que la app creaba sola al cambiar de fase, todavía pendientes.
#
# Desde el 11-oct-2026 cambiar de fase no crea tareas (`Tareas::MoldesRetirados`). Esto encuentra
# las que quedaron de antes —«Primer riego en vegetativo», «Ajustar fotoperiodo a 12/12»…— y las
# cancela. Sólo las que nadie empezó ni cerró, y sólo las sueltas: si una tarea con ese título
# vino de un plan de trabajo, la eligió alguien y no se toca.
#
#   bundle exec rake tareas:cancelar_automaticas              # sólo lista
#   bundle exec rake tareas:cancelar_automaticas CLUB=28      # una organización
#   bundle exec rake tareas:cancelar_automaticas CORREGIR=1   # las cancela
namespace :tareas do
  desc 'Lista las tareas automáticas de fase pendientes (CORREGIR=1 para cancelarlas)'
  task cancelar_automaticas: :environment do
    corregir = ENV['CORREGIR'].present?
    club_id  = ENV['CLUB'].presence

    ActsAsTenant.without_tenant do
      scope = Tarea.where(estado: 'pendiente', titulo: Tareas::MoldesRetirados::TITULOS,
                          origen_plan_id: nil, aplicacion_plan_id: nil, plan_tarea_id: nil)
      scope = scope.where(club_id: club_id.to_i) if club_id

      por_club = scope.group(:club_id).count
      if por_club.empty?
        puts 'No quedan tareas automáticas de fase pendientes.'
        next
      end

      clubes = Club.where(id: por_club.keys).index_by(&:id)
      por_club.each { |cid, n| puts format('%-30s %4d', clubes[cid]&.slug || cid, n) }
      total = por_club.values.sum
      if corregir
        scope.update_all(estado: 'cancelada', updated_at: Time.current)
        puts "#{total} tareas canceladas."
      else
        puts "#{total} tareas. CORREGIR=1 para cancelarlas."
      end
    end
  end
end
