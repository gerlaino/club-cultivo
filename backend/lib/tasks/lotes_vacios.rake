# Lotes en cultivo que se quedaron sin plantas vivas.
#
# Desde el 9-oct-2026 descartar o eliminar la última planta cierra el lote (`Lote#cerrar_sin_plantas!`),
# con aviso antes. Esto encuentra los que quedaron de antes: «Germinación · 0 plantas» para siempre.
#
#   bundle exec rake lotes:cerrar_vacios              # sólo lista
#   bundle exec rake lotes:cerrar_vacios CLUB=28      # una organización
#   bundle exec rake lotes:cerrar_vacios CORREGIR=1   # los cierra sin cosecha
#
# Sólo los que tienen plantas cargadas y TODAS descartadas o eliminadas, y el contador en cero: un
# lote cargado sólo con el número no se toca.
namespace :lotes do
  desc 'Lista los lotes en cultivo sin plantas vivas (CORREGIR=1 para cerrarlos sin cosecha)'
  task cerrar_vacios: :environment do
    corregir = ENV['CORREGIR'].present?
    club_id  = ENV['CLUB'].presence

    ActsAsTenant.without_tenant do
      scope = Lote.where(estado: Lote::CULTIVO_ESTADOS).where('COALESCE(plants_count, 0) = 0')
                  .where(id: Plant.unscoped.select(:lote_id))
                  .where.not(id: Plant.where.not(state: 'descartada').select(:lote_id))
      scope = scope.where(club_id: club_id.to_i) if club_id

      lotes = scope.includes(:club, :genetica).order(:club_id, :id).to_a
      if lotes.empty?
        puts 'Ningún lote en cultivo quedó sin plantas.'
        next
      end

      lotes.each do |l|
        puts format('%-28s %-10s %-12s %s', l.club&.slug, l.codigo, l.estado, l.genetica&.nombre)
        next unless corregir

        ActsAsTenant.with_tenant(l.club) { l.cerrar_sin_plantas! }
      end
      puts corregir ? "#{lotes.size} lotes cerrados sin cosecha." : "#{lotes.size} lotes. CORREGIR=1 para cerrarlos."
    end
  end
end
