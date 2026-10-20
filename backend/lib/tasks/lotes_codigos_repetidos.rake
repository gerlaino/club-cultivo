# Lotes con el mismo código dentro de una organización. `Lote` valida que el código sea único por
# organización, pero lo que escribe sin validar (la mudanza `cultivo:mudar`, `update_columns`) se lo
# saltea, y la base no lo impide. Dos lotes «L-26-001» son dos plantas «L-26-001-P001» en el
# buscador y una trazabilidad que no sabe de cuál se habla (20-oct-2026).
#
# SÓLO LEE. Es el paso previo a decidir un índice único en la base: si hay repetidos, la
# migración fallaría al deployar.
#
#   bundle exec rake lotes:codigos_repetidos
namespace :lotes do
  desc 'Lista los códigos de lote repetidos dentro de una misma organización (sólo lee)'
  task codigos_repetidos: :environment do
    ActsAsTenant.without_tenant do
      repetidos = Lote.unscoped.where(deleted_at: nil).where.not(codigo: [nil, ''])
                      .group(:club_id, :codigo).having('COUNT(*) > 1').count
      if repetidos.empty?
        puts 'Sin códigos de lote repetidos.'
        next
      end

      clubes = Club.unscoped.where(id: repetidos.keys.map(&:first)).index_by(&:id)
      repetidos.keys.group_by(&:first).each do |club_id, pares|
        puts "##{club_id} #{clubes[club_id]&.name}"
        pares.map(&:last).sort.each do |codigo|
          lotes = Lote.unscoped.where(club_id: club_id, codigo: codigo, deleted_at: nil).order(:id)
          puts "  #{codigo}: " + lotes.map { |l| "##{l.id} #{l.estado} (alta #{l.created_at.to_date})" }.join(' · ')
        end
      end
      puts "\nTotal: #{repetidos.size} código(s) repetidos."
    end
  end
end
