# frozen_string_literal: true

# LA HISTORIA DE UN STOCK CON MÁS SOBRE LA MESA QUE EN EL TOTAL (22-oct-2026). SÓLO LEE.
#
# `stocks:mesa_de_mas` dice QUÉ stocks están mal; esto dice CÓMO llegaron ahí, para saber cuál de
# los dos números miente antes de corregir nada. Reconstruye hacia atrás, desde lo que hay hoy,
# el total (movimientos del stock) y la mesa (movimientos del mostrador), y marca:
#   · el primer momento en que la mesa pasó al total, y qué lo hizo;
#   · cada reconteo: cuánto había en total y en la mesa antes, y cuánto se contó. Si lo contado
#     coincide con «total − mesa», se contó SÓLO el depósito y la mesa es real.
#
#   bundle exec rake stocks:historia_mesa                     # todos los que tienen mesa de más
#   bundle exec rake stocks:historia_mesa CODIGOS=ST-26-0026,ST-26-0042
namespace :stocks do
  desc 'Historia (total y mesa) de los stocks con más sobre la mesa que en el total. Sólo lee.'
  task historia_mesa: :environment do
    codigos = ENV['CODIGOS'].to_s.split(',').map(&:strip).reject(&:empty?)
    f = ->(x) { format('%8.2f', x.to_f) }

    ActsAsTenant.without_tenant do
      mesa_hoy = MostradorItem.unscoped.group(:stock_id).sum(:cantidad)
      stocks = if codigos.any?
                 Stock.where(numero_lote_producto: codigos)
               else
                 Stock.where(id: mesa_hoy.keys).select { |s| mesa_hoy[s.id].to_d > s.cantidad.to_d }
               end

      resumen = Hash.new(0)
      stocks.sort_by(&:id).each do |s|
        items = MostradorItem.unscoped.where(stock_id: s.id).pluck(:id)
        eventos = StockMovimiento.where(stock_id: s.id).map do |m|
          { at: m.created_at, lado: :total, delta: m.gramos.to_d, tipo: m.tipo, quien: m.usuario_id, texto: m.notas.to_s }
        end
        eventos += MostradorMovimiento.unscoped.where(mostrador_item_id: items).map do |m|
          { at: m.created_at, lado: :mesa, delta: m.cantidad.to_d, tipo: m.tipo, quien: m.usuario_id, texto: m.motivo.to_s }
        end
        eventos.sort_by! { |e| [e[:at], e[:lado] == :total ? 0 : 1] }

        # Hacia atrás: el valor DESPUÉS de cada evento, partiendo de hoy.
        total = s.cantidad.to_d
        mesa  = mesa_hoy[s.id].to_d
        eventos.reverse_each do |e|
          e[:total_despues] = total
          e[:mesa_despues]  = mesa
          e[:lado] == :total ? total -= e[:delta] : mesa -= e[:delta]
        end

        nombres = User.unscoped.where(id: eventos.map { |e| e[:quien] }.uniq).to_h { |u| [u.id, u.email] }
        puts "\n#{'=' * 100}\n#{s.club&.slug} #{s.numero_lote_producto} (id #{s.id}) — hoy total #{f.(s.cantidad)}  mesa #{f.(mesa_hoy[s.id])}"
        puts "Inicial cargado #{f.(s.cantidad_inicial)} · reconstruido al principio #{f.(total)}" \
             "#{(total - s.cantidad_inicial.to_d).abs > 0.01 ? '  ← NO COINCIDE: hubo cambios del total sin movimiento' : ''}"

        primero = nil
        eventos.each do |e|
          mal = e[:mesa_despues] > e[:total_despues] + 0.001
          marca = mal && primero.nil? ? '  ◀◀ ACÁ LA MESA PASA AL TOTAL' : ''
          primero ||= e if mal
          puts format('%s  %-5s %-13s %+9.2f  → total %s  mesa %s  %-28s %s%s',
                      e[:at].in_time_zone('America/Argentina/Buenos_Aires').strftime('%d/%m %H:%M'),
                      e[:lado], e[:tipo], e[:delta], f.(e[:total_despues]), f.(e[:mesa_despues]),
                      nombres[e[:quien]].to_s[0, 28], e[:texto][0, 60], marca)

          next unless e[:lado] == :total && e[:tipo] == 'ajuste' && e[:texto].include?('[RECONTEO]')

          antes   = e[:total_despues] - e[:delta]
          mesa_en = e[:mesa_despues]
          deposito = antes - mesa_en
          veredicto = if mesa_en.positive? && (e[:total_despues] - deposito).abs <= [deposito.abs * 0.1, 2].max
                        resumen['reconteos que contaron sólo el depósito'] += 1
                        'CONTÓ SÓLO EL DEPÓSITO (lo contado ≈ total − mesa): la mesa es real'
                      elsif mesa_en.zero?
                        'sin nada en la mesa: el reconteo es del total'
                      else
                        resumen['reconteos a mirar a mano'] += 1
                        'no coincide con el depósito: mirar a mano'
                      end
          puts format('      RECONTEO: antes total %s, mesa %s → depósito %s. Contó %s. %s',
                      f.(antes), f.(mesa_en), f.(deposito), f.(e[:total_despues]), veredicto)
        end
        resumen[primero ? "causa: #{primero[:lado]} #{primero[:tipo]}" : 'causa: no se ve en los movimientos'] += 1
      end

      puts "\n#{'=' * 100}\nRESUMEN (#{stocks.size} stocks)"
      resumen.sort.each { |k, v| puts format('  %-45s %d', k, v) }

      # EL OTRO LADO (desde (fu), 20-oct-2026): un reconteo del stock ahora también baja la mesa.
      # Si se contó sólo el depósito, eso sacó de la mesa producto que estaba. Estos ya no aparecen
      # arriba —la mesa quedó igual al total— así que se listan aparte.
      bajadas = MostradorMovimiento.unscoped.where('motivo LIKE ?', 'Reconteo del stock:%').order(:created_at)
      puts "\nMESA BAJADA POR UN RECONTEO DEL STOCK (desde el 20-oct): #{bajadas.size}"
      bajadas.includes(mostrador_item: :stock).each do |m|
        st = m.mostrador_item&.stock
        puts format('  %s  %-12s %+9.2f  %s', m.created_at.in_time_zone('America/Argentina/Buenos_Aires').strftime('%d/%m %H:%M'),
                    st&.numero_lote_producto, m.cantidad.to_f, m.motivo.to_s[0, 70])
      end
    end
  end
end
