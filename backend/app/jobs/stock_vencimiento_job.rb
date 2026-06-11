class StockVencimientoJob < ApplicationJob
  queue_as :default

  def perform
    Club.all.find_each { |club| procesar_club(club) }
  end

  private

  def procesar_club(club)
    hoy = Date.today

    stocks = Stock
      .where(club_id: club.id)
      .where.not(fecha_vencimiento_est: nil)
      .where.not(estado: 'agotado')
      .where('cantidad > 0')

    stocks.each do |stock|
      ev = stock.estado_vencimiento
      next if ev == 'ok'
      next if alerta_reciente?(club, stock.id, ev)

      dias = stock.dias_para_vencimiento
      mensaje = case ev
      when 'vencido'
        "Stock vencido: #{stock.forma_producto.humanize} (#{stock.numero_lote_producto}) — venció hace #{dias.abs} día#{dias.abs == 1 ? '' : 's'}"
      when 'critico'
        "Stock por vencer: #{stock.forma_producto.humanize} (#{stock.numero_lote_producto}) — vence en #{dias} día#{dias == 1 ? '' : 's'}"
      when 'proximo'
        "Stock próximo a vencer: #{stock.forma_producto.humanize} (#{stock.numero_lote_producto}) — vence en #{dias} días"
      end

      severidad = ev == 'vencido' ? 'error' : (ev == 'critico' ? 'warning' : 'info')

      AlertaInterna.create!(
        club:             club,
        tipo:             'stock_vencimiento',
        mensaje:          mensaje,
        severidad:        severidad,
        destinada_a_role: 'admin',
        contexto:         {
          stock_id:            stock.id,
          forma_producto:      stock.forma_producto,
          numero_lote:         stock.numero_lote_producto,
          fecha_vencimiento:   stock.fecha_vencimiento_est.to_s,
          dias_para_vencer:    dias,
          estado_vencimiento:  ev,
        }
      )
    end
  end

  def alerta_reciente?(club, stock_id, estado_vencimiento)
    AlertaInterna.where(club: club, tipo: 'stock_vencimiento')
                 .where("contexto->>'stock_id' = ?", stock_id.to_s)
                 .where("contexto->>'estado_vencimiento' = ?", estado_vencimiento)
                 .where('created_at >= ?', 1.day.ago)
                 .exists?
  end
end
