# Stocks cuyo balance de trazabilidad NO CIERRA: hay más producto del que se produjo.
#
# `producido − dispensado − salidas = en stock` es la cuenta del informe de Trazabilidad. Se
# rompía porque contar de más sobre la mesa SUMABA al inventario del club: producto trazable sin
# origen. El informe no tiene casillero para eso, así que lo escupía como una merma NEGATIVA y
# con "en stock" mayor que "producido" — la señal de que algo apareció de la nada.
#
# La puerta ya está cerrada (`MostradorItem#ajustar_inventario!` no sube nada, y `mover!` no deja
# apartar más de lo que hay libre). Esto encuentra lo que quedó de antes.
#
#   bundle exec rake stocks:balance_descuadrado              # sólo lista
#   bundle exec rake stocks:balance_descuadrado CLUB=28      # una organización
#   bundle exec rake stocks:balance_descuadrado CORREGIR=1   # asienta la corrección
#
# CORREGIR no borra nada: asienta un `ajuste` negativo al lado, con su motivo — misma regla que
# `Mostradores::CorregirCierre`. Borrar para tapar el error es peor que el error.
namespace :stocks do
  desc 'Lista los stocks con más cantidad que la producida (CORREGIR=1 para asentar la corrección)'
  task balance_descuadrado: :environment do
    corregir = ENV['CORREGIR'].present?
    club_id  = ENV['CLUB'].presence

    ActsAsTenant.without_tenant do
      scope = Stock.unscoped.where('cantidad > cantidad_inicial').where.not(cantidad_inicial: nil)
      scope = scope.where(club_id: club_id.to_i) if club_id

      if scope.none?
        puts 'Ningún stock tiene más cantidad que la producida. El balance cierra en todos.'
        next
      end

      puts "#{scope.count} stock(s) con el balance descuadrado:\n\n"
      total = 0.to_d

      scope.order(:club_id, :id).each do |s|
        sintoma = s.cantidad.to_d - s.cantidad_inicial.to_d
        total += sintoma
        puts "  ##{s.id} #{s.numero_lote_producto} · #{nombre_club(s.club_id)}"
        puts "     producido #{s.cantidad_inicial.to_f} · hoy #{s.cantidad.to_f} · " \
             "sobran #{sintoma.round(3).to_f} #{s.unidad || 'g'} sobre lo producido"

        # LO QUE SE SACA ES LO QUE ENTRÓ MAL, NO EL RESIDUO. `cantidad − cantidad_inicial` sirve
        # para DETECTAR, no para corregir: si además hubo dispensaciones, el residuo es más chico
        # que lo que entró de más y la corrección dejaría el stock por encima de lo real.
        sospechosos = ajustes_de_conteo(s)
        # Lo ya devuelto por una corrección anterior no se vuelve a restar: correr esto dos veces
        # dejaría el stock por debajo de lo real, y un rake que empeora al repetirse no se usa.
        ya_corregido = correcciones_previas(s)
        entro_mal    = sospechosos.sum { |m| m.gramos.to_d } - ya_corregido
        otras       = entradas_positivas(s) - sospechosos

        if sospechosos.any?
          puts "     entró por #{sospechosos.size} conteo(s) del mostrador, #{entro_mal.round(3).to_f} a devolver:"
          puts "     (ya se habían devuelto #{ya_corregido.round(3).to_f} en una corrección anterior)" if ya_corregido.positive?
          sospechosos.each { |m| puts "       #{m.created_at.strftime('%d-%m-%Y')} · +#{m.gramos.to_f} · #{m.notas}" }
        end

        if otras.any?
          puts "     y #{otras.size} entrada(s) por OTRA puerta (no se corrigen acá):"
          otras.each { |m| puts "       #{m.created_at.strftime('%d-%m-%Y')} · #{m.tipo} +#{m.gramos.to_f} · #{m.notas}" }
        end

        if sospechosos.empty? && otras.empty?
          puts '     SIN NINGÚN MOVIMIENTO QUE LO EXPLIQUE: la cantidad se editó a mano o viene de'
          puts '     una siembra/clonación. No se corrige solo — mirarlo antes de tocar nada.'
        end

        next unless corregir
        next if sospechosos.empty?

        if entro_mal <= 0
          puts '     ✓ ya estaba corregido: no hay nada que devolver.'
          next
        end

        autor = autor_de(s)
        if autor.nil?
          puts '     ✗ sin admin en esa organización: no hay a nombre de quién asentarlo.'
          next
        end
        corregir!(s, entro_mal, autor)
        puts "     ✓ corregido a nombre de #{autor.email}: queda en #{s.reload.cantidad.to_f}"
      end

      puts "\nTotal por encima de lo producido: #{total.round(3).to_f}"
      puts(corregir ? 'Corregido.' : 'Sólo lectura. Corré con CORREGIR=1 para asentar la corrección.')
    end
  end

  # Los ajustes POSITIVOS que salieron de un conteo del mostrador: la puerta por la que entraba
  # producto sin origen. Se listan para poder decidir mirando, no de memoria.
  def ajustes_de_conteo(stock)
    stock.stock_movimientos
         .where(tipo: 'ajuste')
         .where('gramos > 0')
         .where('notas ILIKE ? OR notas ILIKE ? OR turno_mostrador_id IS NOT NULL',
                '%onteo del mostrador%', '%rqueo del mostrador%')
         .order(:created_at)
         .to_a
  end

  # `StockMovimiento` exige usuario: un movimiento sin autor no se puede auditar. Corriendo por
  # rake no hay sesión, así que se asienta a nombre de un admin de esa organización.
  # Cualquier entrada positiva al stock, venga de donde venga.
  # Lo que este mismo rake ya devolvió antes.
  def correcciones_previas(stock)
    stock.stock_movimientos
         .where(tipo: 'ajuste').where('gramos < 0')
         .where('notas ILIKE ?', '%Corrección de balance%')
         .sum(:gramos).to_d.abs
  end

  def entradas_positivas(stock)
    stock.stock_movimientos.where('gramos > 0').order(:created_at).to_a
  end

  def nombre_club(id)
    @nombres ||= Club.unscoped.pluck(:id, :name).to_h
    "#{@nombres[id] || 'organización'} (##{id})"
  end

  def autor_de(stock)
    User.where(club_id: stock.club_id, role: 'admin').order(:id).first
  end

  def corregir!(stock, sobra, autor)
    stock.with_lock do
      stock.update!(cantidad: [stock.cantidad.to_d - sobra, 0].max)
      stock.stock_movimientos.create!(
        tipo:    'ajuste',
        gramos:  -sobra,
        usuario: autor,
        fecha:   Time.zone.today,
        notas:   'Corrección de balance: había más cantidad que la producida. Entró por un conteo ' \
                 'del mostrador, que sumaba al inventario en vez de apartar del depósito.',
      )
    end
  end
end
