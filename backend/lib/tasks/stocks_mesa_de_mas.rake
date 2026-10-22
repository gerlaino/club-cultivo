# Stocks con más sobre la mesa que en el frasco.
#
#   bundle exec rake stocks:mesa_de_mas              # sólo lista, y dice qué haría
#   bundle exec rake stocks:mesa_de_mas CLUB=28      # una organización
#   bundle exec rake stocks:mesa_de_mas CORREGIR=1   # aplica
#
# QUÉ NÚMERO SE DA POR BUENO (22-oct-2026, Germán: «no quiero quilombos con dispensas ni plata»).
# Con la mesa más grande que el frasco no se sabe cuál miente, y el que se elige es EL TOTAL: la mesa
# baja hasta el total, con su movimiento. Es el lado que no puede inventar nada — nunca aparece un
# gramo que no existe, y el mostrador deja de poder entregar más de lo que hay. Si la mesa era la
# real, el producto sigue ahí: el próximo cierre lo cuenta como sobrante (que no se aplica solo) y
# administración lo carga. No toca dispensas, cobros, cuenta corriente ni asientos.
#
# Un stock con la caja de su mostrador ABIERTA se saltea: el movimiento caería en el arqueo del día.
# Se corre de nuevo cuando cierre. Es idempotente: lo ya corregido no vuelve a aparecer.
namespace :stocks do
  desc 'Stocks con más sobre la mesa que en el frasco; CORREGIR=1 baja la mesa al total'
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

      corregidos = salteados = 0
      stocks.each do |s|
        abierta = MostradorItem.unscoped.where(stock_id: s.id).where('cantidad > 0').includes(:mostrador)
                               .any? { |mi| mi.mostrador&.turno_abierto }
        reservado = ActsAsTenant.with_tenant(s.club) { s.apartado_para_reservas.to_d }
        accion = abierta ? 'SE SALTEA: caja abierta, correr cuando cierre' : "mesa #{mesa[s.id].to_f} → #{s.cantidad.to_f}"
        accion += "  (reservado #{reservado.to_f})" if reservado.positive?
        puts format('%-28s %-12s total %8.2f  mesa %8.2f  %s', s.club&.slug, s.numero_lote_producto, s.cantidad.to_f,
                    mesa[s.id].to_f, accion)
        if abierta
          salteados += 1
          next
        end
        next unless corregir

        ActsAsTenant.with_tenant(s.club) do
          admin = s.club.users.where(role: 'admin').order(:id).first
          abort "#{s.club.slug} no tiene admin: el movimiento necesita autor" if admin.nil?

          s.bajar_mesa_al_total!(usuario: admin,
                                 motivo: 'Corrección 22-oct-2026: la mesa tenía más que el frasco; se tomó el total como bueno')
        end
        corregidos += 1
      end
      puts(corregir ? "#{corregidos} corregidos, #{salteados} salteados por caja abierta." :
                      "#{stocks.size} stocks (#{salteados} con caja abierta). CORREGIR=1 baja la mesa al total.")
    end
  end
end
