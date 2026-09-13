module Analitica
  # EL UNIVERSO DE LA ANALÍTICA: los lotes CERRADOS CON RENDIMIENTO, cosechados en el período
  # elegido (o todos, que es el default: para comparar hacen falta muchos lotes). Cada solapa
  # contesta una pregunta sobre este mismo conjunto —qué genética, cuánto tarda, en qué sala, a
  # qué costo— y por eso lo que se calcula por lote vive acá una sola vez: plantas y su
  # prendimiento, la duración de cada fase, la sala y la ventana de la floración.
  #
  # Nada se promedia entre promedios: g/planta es suma de gramos ÷ suma de plantas cosechadas, y
  # todo porcentaje se arma con sus dos sumas. Es lo que hace comparable un lote de 3 plantas con
  # uno de 40 (la misma corrección que llevó Plan vs. real).
  class Universo
    # Las fases del lote tal como existen, en orden. `cosecha` es el secado (el lote cuelga);
    # el viejo cálculo usaba una fase `secado` que no es un estado y dejaba tres columnas vacías.
    FASES = %w[enraizado vegetativo floracion cosecha en_manicura curado].freeze
    MINIMO_LOTES = 3   # debajo, la fila se muestra sin conclusión (decisión de Germán, 13-sep)

    attr_reader :club, :desde, :hasta

    def initialize(club:, desde: nil, hasta: nil)
      @club  = club
      @desde = desde
      @hasta = hasta
    end

    def lotes
      @lotes ||= begin
        base = club.lotes.where('rendimiento_real_g > 0').includes(:genetica, :sala, :sede, :costo_lote)
        if desde || hasta
          ids = fechas_cosecha.select { |_, f| (desde.nil? || f >= desde) && (hasta.nil? || f <= hasta) }.keys
          base = base.where(id: ids)
        end
        base.to_a
      end
    end

    def ids = lotes.map(&:id)
    def suficientes?(n) = n >= MINIMO_LOTES

    # Cuándo se cortó cada lote: su primer paso post-cosecha (como Producción). Nunca `updated_at`.
    def fechas_cosecha
      @fechas_cosecha ||= LoteEvento.where(lote_id: club.lotes.select(:id), tipo: 'cambio_estado',
                                           estado_nuevo: Informes::Produccion::POST_COSECHA)
                                    .group(:lote_id).minimum(:registrado_en)
    end

    # Plantas por lote: todas las que alguna vez tuvo (`unscoped`: las descartadas incluidas, o el
    # que no prendió desaparece del denominador), cuántas no prendieron y cuántas se perdieron
    # después de prender. El viejo cálculo dividía por `plants_count`, que YA excluye las
    # descartadas: la «merma» daba siempre 0.
    def plantas
      @plantas ||= begin
        base = Plant.unscoped.where(lote_id: ids, deleted_at: nil)
        total    = base.group(:lote_id).count
        descart  = base.where(state: 'descartada').group(:lote_id).count
        noprend  = base.where(motivo_descarte: 'no_prendio').group(:lote_id).count
        lotes.to_h do |l|
          t = total[l.id].to_i
          # Un lote viejo sin plantas registradas una por una: manda el contador, sin descartes.
          t = (l.plants_count_cosechadas || l.plants_count).to_i if t.zero?
          [l.id, { total: t, descartadas: descart[l.id].to_i, no_prendio: noprend[l.id].to_i,
                   cosechadas: (l.plants_count_cosechadas || [t - descart[l.id].to_i, 0].max).to_i }]
        end
      end
    end

    # Días en cada fase, por lote, de la cronología real: cada cambio de estado dura hasta el
    # siguiente. Y `total`: la suma de las fases hasta que existe el frasco (entrada a `curado`).
    def fases
      @fases ||= begin
        eventos = LoteEvento.where(lote_id: ids, tipo: 'cambio_estado').order(:registrado_en)
                            .group_by(&:lote_id)
        lotes.to_h do |l|
          evs = eventos[l.id] || []
          dias = {}
          evs.each_with_index do |ev, i|
            sig = evs[i + 1]
            next if sig.nil? || !FASES.include?(ev.estado_nuevo)

            d = ((sig.registrado_en - ev.registrado_en) / 86_400.0).round(1)
            dias[ev.estado_nuevo] = (dias[ev.estado_nuevo] || 0) + d
          end
          # Un lote heredado arranca en `start_date` sin evento: el vegetativo va desde ahí.
          if dias['vegetativo'].nil? && l.start_date && (flo = evs.find { |e| e.estado_nuevo == 'floracion' })
            dias['vegetativo'] = ((flo.registrado_en.to_date - l.start_date).to_i).to_f
          end
          # La suma de las fases hasta que existe el frasco: es exactamente lo que suman las
          # columnas, así el total nunca contradice a la fila.
          hasta_frasco = %w[enraizado vegetativo floracion cosecha en_manicura].filter_map { |f| dias[f] }
          [l.id, dias.merge('total' => (hasta_frasco.any? ? hasta_frasco.sum.round(1) : nil))]
        end
      end
    end

    # Dónde y cuándo floreció cada lote: la sala a la que entró en floración (el lote pierde la
    # sala al cosecharse, así que `lote.sala_id` no sirve) y la ventana hasta el corte. Es contra
    # esto que se mira el ambiente: lo que la planta vivió, no el promedio del ciclo entero.
    def floracion
      @floracion ||= begin
        eventos = LoteEvento.where(lote_id: ids, tipo: 'cambio_estado').order(:registrado_en)
                            .includes(:sala_destino).group_by(&:lote_id)
        lotes.to_h do |l|
          evs = eventos[l.id] || []
          flo = evs.find { |e| e.estado_nuevo == 'floracion' }
          corte = flo && evs.find { |e| e.registrado_en > flo.registrado_en && Informes::Produccion::POST_COSECHA.include?(e.estado_nuevo) }
          sala  = flo&.sala_destino || l.sala
          [l.id, { sala_id: sala&.id, sala: sala&.nombre, desde: flo&.registrado_en, hasta: corte&.registrado_en }]
        end
      end
    end

    def sede_de(lote) = lote.sede || lote.sala&.sede
  end
end
