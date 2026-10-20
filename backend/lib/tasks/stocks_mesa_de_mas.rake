# Stocks con más sobre la mesa que en el frasco.
#
# Hasta el 20-oct-2026 ajustar, finalizar, producir o editar un stock bajaba el total sin tocar la
# mesa: ST-26-0028 quedó con 70 g y «132 sobre la mesa». Desde ese día lo hace
# `Stock#bajar_mesa_al_total!`; esto encuentra los que quedaron de antes.
#
#   bundle exec rake stocks:mesa_de_mas              # sólo lista
#   bundle exec rake stocks:mesa_de_mas CLUB=28      # una organización
#   bundle exec rake stocks:mesa_de_mas CORREGIR=1   # baja la mesa al total, con movimiento
#
# El movimiento queda a nombre del primer admin de la organización, con el motivo dicho.
namespace :stocks do
  desc 'Lista los stocks con más sobre la mesa que en el frasco (CORREGIR=1 para bajar la mesa)'
  task mesa_de_mas: :environment do
    corregir = ENV['CORREGIR'].present?
    club_id  = ENV['CLUB'].presence

    ActsAsTenant.without_tenant do
      mesa = MostradorItem.unscoped.where('cantidad > 0').group(:stock_id).sum(:cantidad)
      scope = Stock.where(id: mesa.keys)
      scope = scope.where(club_id: club_id.to_i) if club_id
      stocks = scope.includes(:club).order(:club_id, :id).select { |s| mesa[s.id].to_d > s.cantidad.to_d }

      if stocks.empty?
        puts 'Ningún stock tiene más sobre la mesa que en el frasco.'
        next
      end

      stocks.each do |s|
        puts format('%-28s %-12s frasco %8.2f  mesa %8.2f  %s', s.club&.slug, s.numero_lote_producto, s.cantidad.to_f,
                    mesa[s.id].to_f, s.estado)
        next unless corregir

        ActsAsTenant.with_tenant(s.club) do
          admin = s.club.users.find_by(role: 'admin')
          s.bajar_mesa_al_total!(usuario: admin, motivo: 'Corrección: la mesa tenía más que el frasco tras un ajuste del stock')
        end
      end
      puts corregir ? "#{stocks.size} stocks corregidos." : "#{stocks.size} stocks. CORREGIR=1 para bajar la mesa al total."
    end
  end
end
