module Riegos
  # Recupera el volumen de agua de los riegos anteriores al 29-sep-2026, que se guardaba como texto
  # en `observaciones`. Lee SÓLO lo que la misma app escribía:
  #   - registro del lote o de la sala: «Riego: 20L»;
  #   - riego de una cama con lotes: «Riego de la Cama A: 30 L en toda la cama».
  # Un riego de sala (o de cama) creó un registro por lote con el mismo texto, de la misma persona,
  # en el mismo momento: ese grupo es UN riego, el volumen es el TOTAL y a cada lote le toca su
  # parte (`RegistroAmbiental.repartir_volumen!`, la regla de ahora). Nunca pisa un volumen cargado.
  class VolumenDesdeTexto
    LOTE = /Riego: (\d+(?:[.,]\d+)?)\s*L\b/
    CAMA = /\ARiego de la .+?: (\d+(?:\.\d+)?) L en toda la cama/
    VENTANA = 10.seconds

    Resultado = Struct.new(:riegos, :registros, :compartidos, keyword_init: true)

    def initialize(scope: RegistroAmbiental.all, confirmar: false)
      @scope = scope
      @confirmar = confirmar
    end

    def call
      candidatos = @scope.where(volumen_l: nil).where('observaciones LIKE ?', '%Riego%L%').includes(:lote).to_a
      vistos = Set.new
      riegos = registros = compartidos = 0
      candidatos.each do |r|
        next if vistos.include?(r.id)
        total = volumen_de(r.observaciones)
        next unless total
        grupo = hermanos(r, candidatos)
        grupo.each { |g| vistos << g.id }
        riegos += 1
        registros += grupo.size
        compartidos += 1 if grupo.size > 1
        RegistroAmbiental.repartir_volumen!(grupo, total) if @confirmar
      end
      Resultado.new(riegos: riegos, registros: registros, compartidos: compartidos)
    end

    private

    def volumen_de(texto)
      m = texto.to_s.match(CAMA) || texto.to_s.match(LOTE)
      m && m[1].tr(',', '.').to_d.then { |v| v.positive? ? v : nil }
    end

    # Los registros del mismo riego: mismo texto, misma persona, casi el mismo momento, lotes de la
    # misma sala (o de la misma cama, que dice su nombre en el texto).
    def hermanos(r, candidatos)
      candidatos.select do |o|
        o.club_id == r.club_id && o.user_id == r.user_id && o.observaciones == r.observaciones &&
          (o.created_at - r.created_at).abs <= VENTANA &&
          (o.observaciones.match?(CAMA) || o.lote&.sala_id == r.lote&.sala_id)
      end
    end
  end
end
