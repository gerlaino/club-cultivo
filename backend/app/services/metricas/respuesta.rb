# REGISTRA CUÁNTO TARDÓ UN PEDIDO, sumándolo a la fila de su hora (ver la migración
# `CrearMetricasRespuesta`). Un solo `INSERT … ON CONFLICT` por pedido: no se guarda cada pedido,
# se suman. Nunca levanta: medir no puede romper lo que se mide.
module Metricas
  class Respuesta
    # Franjas en milisegundos: b0 < 100, b1 < 250, b2 < 500, b3 < 1000, b4 < 1500, b5 < 3000,
    # b6 < 6000, b7 el resto.
    FRANJAS_MS = [100, 250, 500, 1000, 1500, 3000, 6000].freeze
    # Lo que no es la app atendiendo a alguien: el monitor externo y el propio panel.
    IGNORAR = %w[Rails::HealthController SaludController].freeze

    def self.registrar(endpoint:, ms:, club_id: nil, hora: Time.current)
      return if endpoint.blank? || IGNORAR.any? { |c| endpoint.start_with?(c) }

      ms     = ms.to_f.round
      franja = FRANJAS_MS.index { |tope| ms < tope } || FRANJAS_MS.size
      sql = <<~SQL
        INSERT INTO metricas_respuesta (hora, endpoint, club_id, cantidad, total_ms, max_ms, b#{franja})
        VALUES ($1, $2, $3, 1, $4::bigint, $4::integer, 1)
        ON CONFLICT (hora, endpoint, club_id) DO UPDATE SET
          cantidad = metricas_respuesta.cantidad + 1,
          total_ms = metricas_respuesta.total_ms + EXCLUDED.total_ms,
          max_ms   = GREATEST(metricas_respuesta.max_ms, EXCLUDED.max_ms),
          b#{franja} = metricas_respuesta.b#{franja} + 1
      SQL
      ActiveRecord::Base.connection.exec_query(sql, 'Metricas::Respuesta',
        [hora.beginning_of_hour, endpoint.to_s[0, 120], club_id.to_i, ms])
    rescue StandardError => e
      Rails.logger.warn("[metricas] #{e.class} #{e.message}")
    end

    # El percentil aproximado de una fila (o una suma de filas): el techo de la franja donde cae.
    # Para la última franja, el máximo visto.
    def self.percentil(fila, p = 0.75)
      total = fila['cantidad'].to_i
      return nil if total.zero?

      objetivo = (total * p).ceil
      acumulado = 0
      (0..7).each do |i|
        acumulado += fila["b#{i}"].to_i
        return [FRANJAS_MS[i] || fila['max_ms'].to_i, fila['max_ms'].to_i].min if acumulado >= objetivo
      end
      fila['max_ms'].to_i
    end
  end
end
