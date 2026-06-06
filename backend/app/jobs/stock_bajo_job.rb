class StockBajoJob < ApplicationJob
  queue_as :default

  UMBRAL_G_DEFAULT = 50

  def perform
    Club.all.find_each { |club| procesar_club(club) }
  end

  private

  def procesar_club(club)
    umbral = club.umbral_stock_g.presence || UMBRAL_G_DEFAULT

    stocks_bajos = Stock
      .where(club_id: club.id, unidad: 'g')
      .where.not(estado: 'agotado')
      .where('cantidad < ? AND cantidad > 0', umbral)
      .to_a

    return if stocks_bajos.empty?

    stocks_data = stocks_bajos.map do |s|
      {
        id:         s.id,
        forma:      s.forma_producto.humanize,
        cantidad_g: s.cantidad.to_f.round(1),
        sede_id:    s.sede_id,
        alerta:     true,
      }
    end

    stocks_data.each do |s|
      next if alerta_reciente?(club, s[:id])

      AlertaInterna.create!(
        club:             club,
        tipo:             'stock_bajo',
        mensaje:          "Stock bajo: #{s[:forma]} — #{s[:cantidad_g]}g disponibles (umbral: #{umbral}g)",
        severidad:        'warning',
        destinada_a_role: 'admin',
        contexto:         { stock_id: s[:id], cantidad_g: s[:cantidad_g], umbral_g: umbral }
      )
    end

    NotificacionesMailer.stock_bajo(club: club, stocks_data: stocks_data).deliver_later
  end

  def alerta_reciente?(club, stock_id)
    AlertaInterna.where(club: club, tipo: 'stock_bajo')
                 .where("contexto->>'stock_id' = ?", stock_id.to_s)
                 .where('created_at >= ?', 1.day.ago)
                 .exists?
  end
end
