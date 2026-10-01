namespace :stocks do
  # LOS MOVIMIENTOS DE DISPENSA CON LA FECHA DE LA DISPENSA (1-oct-2026). Hasta hoy el movimiento
  # de stock que deja una dispensa se fechaba el día en que se cargó: una entrega del 10 de agosto
  # cargada en septiembre salía en septiembre en Pérdidas, la trazabilidad y todo lo que corta por
  # período. Esto le pone a cada movimiento la `fecha_dispensacion` de su dispensa.
  #
  #   rake stocks:fechar_movimientos_de_dispensa              # cuenta qué cambiaría, NO escribe
  #   rake stocks:fechar_movimientos_de_dispensa CONFIRMAR=1  # escribe
  #   CLUB_ID=3 rake stocks:fechar_movimientos_de_dispensa    # un solo club
  #
  # Idempotente. Sólo toca los movimientos vinculados por `dispensacion_id`; los viejos sin vínculo
  # (los reconocía el texto de la nota) se cuentan y no se tocan.
  desc 'Fecha los movimientos de stock de cada dispensa con la fecha de la dispensa'
  task fechar_movimientos_de_dispensa: :environment do
    confirmar = ENV['CONFIRMAR'].present?
    ActsAsTenant.without_tenant do
      movs = StockMovimiento.where(tipo: 'dispensacion').where.not(dispensacion_id: nil)
                            .joins('INNER JOIN dispensaciones ON dispensaciones.id = stock_movimientos.dispensacion_id')
                            .where('stock_movimientos.fecha IS DISTINCT FROM dispensaciones.fecha_dispensacion')
      movs = movs.where(dispensaciones: { club_id: ENV['CLUB_ID'] }) if ENV['CLUB_ID'].present?
      n = movs.count
      sin_vinculo = StockMovimiento.where(tipo: 'dispensacion', dispensacion_id: nil)
      sin_vinculo = sin_vinculo.joins(:stock).where(stocks: { club_id: ENV['CLUB_ID'] }) if ENV['CLUB_ID'].present?

      puts "#{n} movimientos de dispensa con otra fecha que su dispensa."
      puts "#{sin_vinculo.count} movimientos de dispensa sin vínculo a la dispensa (no se tocan)."
      if confirmar && n.positive?
        StockMovimiento.where(id: movs.select(:id))
                       .update_all('fecha = (SELECT d.fecha_dispensacion FROM dispensaciones d WHERE d.id = stock_movimientos.dispensacion_id)')
        puts '✓ Escrito.'
      elsif !confirmar
        puts 'No se escribió nada: correlo con CONFIRMAR=1.'
      end
    end
  end
end
