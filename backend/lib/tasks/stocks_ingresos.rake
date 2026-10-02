# LO QUE ENTRÓ CARGADO COMO RECONTEO (1-oct-2026).
#
# Hasta hoy, la mercadería que llegaba a un stock externo que ya existía se cargaba con «Ajustar →
# Reconteo → + Agregar»: era el único camino. Los informes leían esos movimientos como una
# corrección de conteo, y lo que entró en octubre a un stock creado en septiembre no aparecía como
# ingreso en ningún mes. Ahora hay «Entró mercadería» (movimiento `ingreso`); esto pasa a `ingreso`
# los reconteos positivos de stock externo que eran, en realidad, mercadería que entró.
#
# Ojo: un reconteo positivo también puede ser «conté y había 12 g más» (eso NO es un ingreso), y
# en la base los dos se ven igual. Por eso primero se LISTA y se mira con quien los cargó; lo que
# era una corrección se deja afuera con EXCLUIR.
#
#   bundle exec rake stocks:ingresos_desde_reconteo                          # sólo lista
#   bundle exec rake stocks:ingresos_desde_reconteo CLUB=28 DESDE=2026-10-01
#   bundle exec rake stocks:ingresos_desde_reconteo EXCLUIR=812,815 CONFIRMAR=1
#
# No toca cantidades: el stock ya tiene esos gramos. Sólo cambia cómo se llama el movimiento, y la
# nota lo dice para que quede el rastro de que se reclasificó.
namespace :stocks do
  desc 'Pasa a «ingreso» los reconteos positivos de stock externo (CONFIRMAR=1 para hacerlo)'
  task ingresos_desde_reconteo: :environment do
    confirmar = ENV['CONFIRMAR'].present?
    excluir   = ENV['EXCLUIR'].to_s.split(',').map(&:strip).reject(&:empty?).map(&:to_i)
    desde     = ENV['DESDE'].presence && Date.iso8601(ENV['DESDE'])

    ActsAsTenant.without_tenant do
      movs = StockMovimiento.joins(:stock)
                            .where(tipo: 'ajuste', turno_mostrador_id: nil, stocks: { origen: 'compra_externa' })
                            .where('stock_movimientos.gramos > 0')
                            .where('stock_movimientos.notas LIKE ?', '[RECONTEO]%')
      movs = movs.where(stocks: { club_id: ENV['CLUB'].to_i }) if ENV['CLUB'].present?
      movs = movs.where('COALESCE(stock_movimientos.fecha, stock_movimientos.created_at::date) >= ?', desde) if desde
      movs = movs.includes(stock: :genetica).order('stocks.club_id', :fecha, :id).to_a

      if movs.empty?
        puts 'No hay reconteos positivos de stock externo para reclasificar.'
        next
      end

      nombres = Club.unscoped.where(id: movs.map { |m| m.stock.club_id }.uniq).pluck(:id, :name).to_h
      movs.group_by { |m| m.stock.club_id }.each do |club_id, ms|
        puts "\n#{nombres[club_id] || 'organización'} (##{club_id}) — #{ms.size} movimiento(s):"
        ms.each do |m|
          s = m.stock
          marca = excluir.include?(m.id) ? '  (EXCLUIDO)' : ''
          puts "  mov ##{m.id} · #{(m.fecha || m.created_at.to_date).strftime('%d-%m-%Y')} · " \
               "#{s.numero_lote_producto || "stock ##{s.id}"} #{s.genetica&.nombre || s.descripcion} · " \
               "+#{m.gramos.to_f} #{s.unidad || 'g'} · #{m.notas}#{marca}"
        end
      end

      a_pasar = movs.reject { |m| excluir.include?(m.id) }
      puts "\n#{a_pasar.size} a pasar a ingreso, #{movs.size - a_pasar.size} excluido(s)."
      unless confirmar
        puts 'Sólo lectura. Lo que fue una corrección de conteo (no mercadería que entró) va en EXCLUIR=id,id; ' \
             'después correr con CONFIRMAR=1.'
        next
      end

      StockMovimiento.transaction do
        a_pasar.each do |m|
          detalle = m.notas.to_s.sub(/\A\[RECONTEO\]\s*/, '')
          m.update!(tipo: 'ingreso', notas: "[INGRESO] (cargado como reconteo) #{detalle}".strip)
        end
      end
      puts "✓ #{a_pasar.size} movimiento(s) pasados a ingreso."
    end
  end
end
