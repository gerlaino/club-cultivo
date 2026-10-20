# Dispensas de las organizaciones DEMO con la línea duplicada (y su historial con «Avance a floracion»).
#
# Hasta el 20-oct-2026 `Clubs::SembrarDemo` creaba la línea a mano y el modelo creaba otra
# (`asegurar_item_espejo`): cada dispensa del Club Modelo mostraba dos renglones con un total de uno.
# El stock se descontó una sola vez (el after_create corre antes de la segunda línea), así que
# borrar la sobrante deja todo cuadrado.
#
#   bundle exec rake demo:corregir              # sólo lista
#   bundle exec rake demo:corregir CORREGIR=1   # borra la línea sobrante
#
# Sólo toca organizaciones con `demo: true`: en una real una línea repetida puede ser legítima.
namespace :demo do
  desc 'Lista las dispensas de las organizaciones demo con la línea duplicada (CORREGIR=1 para borrarla)'
  task corregir: :environment do
    corregir = ENV['CORREGIR'].present?

    ActsAsTenant.without_tenant do
      demos = Club.unscoped.demo.pluck(:id)
      items = DispensacionItem.joins(dispensacion: :paciente)
                              .where(pacientes: { club_id: demos })
                              .order(:id).to_a
      sobrantes = items.group_by { |i| [i.dispensacion_id, i.stock_id, i.cantidad] }
                       .values.select { |g| g.size > 1 }.flat_map { |g| g.drop(1) }

      # Y el historial de sus lotes decía «Avance a floracion»: el identificador, no la palabra.
      eventos = LoteEvento.unscoped.where(club_id: demos, tipo: 'cambio_estado')
                          .where("descripcion ~ '^Avance a [a-z_]+$'").includes(:lote).to_a
      puts "#{eventos.size} eventos «Avance a …» con el identificador de la fase."
      if corregir
        eventos.each do |e|
          e.update_columns(descripcion: "Avance a #{Lote.etiqueta_estado(e.estado_nuevo, e.lote&.origen)}")
        end
      end

      if sobrantes.empty?
        puts 'Ninguna dispensa demo tiene la línea duplicada.'
        next
      end

      por_club = Dispensacion.unscoped.where(id: sobrantes.map(&:dispensacion_id)).joins(:paciente)
                             .group('pacientes.club_id').count
      por_club.each { |cid, n| puts format('%-28s %5d dispensas', Club.unscoped.find(cid).slug, n) }
      if corregir
        DispensacionItem.where(id: sobrantes.map(&:id)).delete_all
        puts "#{sobrantes.size} líneas sobrantes borradas."
      else
        puts "#{sobrantes.size} líneas sobrantes. CORREGIR=1 para borrarlas."
      end
    end
  end
end
