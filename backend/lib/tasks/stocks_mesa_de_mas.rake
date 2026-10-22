# Stocks con más sobre la mesa que en el frasco. SÓLO LISTA.
#
#   bundle exec rake stocks:mesa_de_mas              # todos
#   bundle exec rake stocks:mesa_de_mas CLUB=28      # una organización
#
# CORREGIR=1 QUEDÓ APAGADO (22-oct-2026). Bajaba la mesa al total, suponiendo que el total era el
# bueno. La causa resultó ser el reconteo que pesaba sólo el depósito y lo cargaba como total: muchas
# veces la mesa es la real y lo que borraba existía. Se corrige recontando cada stock desde su ficha
# (depósito y mesa por separado, `Stocks::Recontar`); `stocks:historia_mesa` dice cómo llegó cada uno.
namespace :stocks do
  desc 'Lista los stocks con más sobre la mesa que en el frasco (sólo lista)'
  task mesa_de_mas: :environment do
    if ENV['CORREGIR'].present?
      abort 'CORREGIR=1 ya no existe: bajaría producto que puede estar sobre la mesa. Recontá cada stock ' \
            '(depósito y mesa por separado) desde su ficha; `rake stocks:historia_mesa` muestra cómo llegó.'
    end
    club_id = ENV['CLUB'].presence

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
      end
      puts "#{stocks.size} stocks. Recontalos desde su ficha: depósito y mesa por separado."
    end
  end
end
