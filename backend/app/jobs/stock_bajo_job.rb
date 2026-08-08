class StockBajoJob < ApplicationJob
  queue_as :default

  UMBRAL_G_DEFAULT = 50

  def perform
    cada_club_con(:produccion_dispensa) { |club| procesar_club(club) }
  end

  private

  # Stock bajo = poca FLOR SECA. Se mira el TOTAL disponible por SEDE (no por contenedor
  # individual, y los derivados quedan afuera — son inventario). Una alerta por sede que
  # maneje flor seca y esté por debajo del umbral del club.
  def procesar_club(club)
    umbral = (club.umbral_stock_g.presence || UMBRAL_G_DEFAULT).to_d
    bajos  = []

    club.sedes.find_each do |sede|
      flor = Stock.where(club_id: club.id, sede_id: sede.id, forma_producto: 'flor_seca', unidad: 'g')
      next unless flor.exists? # solo sedes que efectivamente manejan flor seca

      disponible = flor.where.not(estado: 'agotado').sum(:cantidad).to_d
      next if disponible >= umbral
      next if alerta_reciente?(club, sede.id)

      AlertaInterna.create!(
        club:             club,
        tipo:             'stock_bajo',
        mensaje:          "Stock de flor seca bajo en #{sede.nombre}: #{disponible.to_f.round(1)}g (umbral: #{umbral.to_i}g)",
        severidad:        'warning',
        destinada_a_role: 'admin',
        contexto:         { sede_id: sede.id, sede_nombre: sede.nombre, total_g: disponible.to_f, umbral_g: umbral.to_f },
      )
      bajos << { forma: "Flor seca · #{sede.nombre}", cantidad_g: disponible.to_f.round(1) }
    end

    return if bajos.empty?

    NotificacionesMailer.stock_bajo(club: club, stocks_data: bajos).deliver_now
  end

  def alerta_reciente?(club, sede_id)
    AlertaInterna.where(club: club, tipo: 'stock_bajo')
                 .where("contexto->>'sede_id' = ?", sede_id.to_s)
                 .where('created_at >= ?', 1.day.ago)
                 .exists?
  end
end
