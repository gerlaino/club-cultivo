module Riegos
  # Un riego que hizo un aparato queda en el lote igual que uno a mano: un RegistroAmbiental con la
  # tarea «riego» y los litros, que es lo que cuentan el historial y el resumen del ciclo. Lo firma
  # el dispositivo, no una persona («Automático · <nombre>»).
  #
  # El aparato riega una línea, no un lote: sabe cuántos ml le dio a CADA maceta, no de quién es
  # cada una. Por eso el riego se reparte a todos los lotes en cultivo de su sala, y los litros de
  # cada lote salen de sus plantas vivas × los ml por maceta.
  #
  # Quedan afuera los que enraízan (viven en la bandeja o el propagador, no en la línea de goteo) y
  # los que están en una cama de suelo vivo (el riego de la cama se registra en la cama).
  #
  # Idempotente por (dispositivo, momento): el aparato reintenta si no le llegó la respuesta, y el
  # mismo riego no puede contarse dos veces.
  class RegistrarDesdeDispositivo
    Resultado = Struct.new(:registros, :duplicado, :error, keyword_init: true)

    # Más que esto en una sola vez no es un riego, es un aparato mal configurado.
    TOPE_ML_POR_MACETA = 20_000

    def initialize(dispositivo, ml_por_maceta:, timestamp: nil)
      @dispositivo   = dispositivo
      @ml_por_maceta = ml_por_maceta
      @timestamp     = timestamp
    end

    def call
      ml = begin
        Float(@ml_por_maceta)
      rescue ArgumentError, TypeError
        nil
      end
      unless ml&.positive? && ml <= TOPE_ML_POR_MACETA
        return error("ml_por_maceta tiene que ser un número entre 1 y #{TOPE_ML_POR_MACETA}")
      end

      cuando = momento
      return error('timestamp inválido o en el futuro') unless cuando

      previos = RegistroAmbiental.where(dispositivo_id: @dispositivo.id, registrado_en: cuando).to_a
      return Resultado.new(registros: previos, duplicado: true) if previos.any?

      lotes = @dispositivo.sala.lotes.where(estado: Lote::CULTIVO_ESTADOS).where.not(estado: 'enraizado')
                          .where(cama_id: nil).to_a
      return error('No hay lotes en cultivo en la sala de este dispositivo') if lotes.empty?

      vivas = Plant.where(lote_id: lotes.map(&:id)).where.not(state: 'descartada').group(:lote_id).count

      registros = RegistroAmbiental.transaction do
        lotes.map do |lote|
          macetas = vivas[lote.id] || lote.plants_count.to_i
          macetas = 1 if macetas <= 0
          RegistroAmbiental.create!(
            lote: lote, club_id: lote.club_id, dispositivo: @dispositivo, user: nil,
            fuente: 'dispositivo', tareas_realizadas: ['riego'],
            litros: (ml * macetas / 1000.0).round(2), registrado_en: cuando,
            observaciones: "Riego automático: #{ml.round} ml por maceta × #{macetas}"
          )
        end
      end
      Resultado.new(registros: registros, duplicado: false)
    end

    private

    def error(msg) = Resultado.new(registros: [], duplicado: false, error: msg)

    # Epoch en segundos, como el webhook de lecturas. Sin timestamp es ahora. Unos minutos de
    # adelanto se toleran (el reloj del aparato no es perfecto); más, es un reloj roto.
    def momento
      return Time.current.change(usec: 0) if @timestamp.blank?
      t = Time.zone.at(Integer(@timestamp.to_s))
      t > 10.minutes.from_now ? nil : t
    rescue ArgumentError, TypeError
      nil
    end
  end
end
