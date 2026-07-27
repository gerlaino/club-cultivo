# Deduplica los depósitos de sistema (mismo club + sede + clave_sistema).
#
# Los duplicados los creó una race condition en la siembra (dos requests simultáneos del mismo
# club): la unicidad era solo validación de modelo, sin índice en la tabla. Ya está cerrado por
# los dos lados (lock en Finanzas::SembrarDepositos + índice único parcial), esta tarea limpia
# los datos que quedaron creados antes.
#
# Uso:
#   DRY_RUN=1 bundle exec rake depositos:deduplicar          # en seco: solo reporta
#   bundle exec rake depositos:deduplicar                    # todos los clubes
#   CLUB_ID=3 bundle exec rake depositos:deduplicar          # un club
#
# Qué hace por cada grupo duplicado: se queda con el id más bajo, le mueve los insumos y los
# productos del bar, y retira el resto (soft-delete → recuperable). Idempotente.
namespace :depositos do
  desc 'Retira los depósitos de sistema duplicados (mismo club + sede + clave)'
  task deduplicar: :environment do
    dry_run = ENV['DRY_RUN'].present?

    ActsAsTenant.without_tenant do
      clubes = ENV['CLUB_ID'].present? ? Club.where(id: ENV['CLUB_ID']) : Club.all
      puts "Modo: #{dry_run ? 'DRY RUN (no escribe)' : 'REAL'} · #{clubes.count} club(es)"
      puts '-' * 70

      total_retirados = 0

      clubes.find_each do |club|
        grupos = Deposito.unscoped
                         .where(club_id: club.id, deleted_at: nil).where.not(clave_sistema: nil)
                         .group_by { |d| [d.clave_sistema, d.sede_id] }
                         .select { |_k, deps| deps.size > 1 }
        next if grupos.empty?

        puts "Club ##{club.id} #{club.name}"
        grupos.each do |(clave, sede_id), deps|
          ids = deps.map(&:id).sort
          puts "  #{clave} (sede #{sede_id || 'nil'}): #{ids.join(', ')} → se queda #{ids.first}"
        end

        if dry_run
          total_retirados += grupos.sum { |_k, deps| deps.size - 1 }
          next
        end

        r = Finanzas::DeduplicarDepositos.new(club).call
        total_retirados += r[:retirados].size
        puts "  retirados: #{r[:retirados].join(', ')} · insumos movidos: #{r[:insumos]} · productos del bar: #{r[:productos]}"
      end

      puts '-' * 70
      puts "#{dry_run ? 'Se retirarían' : 'Retirados'}: #{total_retirados} depósito(s) duplicado(s)"
    end
  end
end
