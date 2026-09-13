module Informes
  # EL INFORME INASE contesta qué variedades del Catálogo Nacional cultiva la organización y cuánto
  # produjo de cada una. Se presenta ante el organismo: UNA FILA POR VARIEDAD ACREDITABLE, con las
  # genéticas propias que acredita debajo (así el informe se audita solo, sin ir a Genéticas).
  #
  # Vivía inline en `InformesController#inase` y contaba DE TODA LA VIDA: era el único informe sin
  # período, una organización de tres años declaraba en 2026 los gramos de 2024. Ahora el criterio
  # es el de Producción —UN LOTE PERTENECE AL PERÍODO EN QUE SE COSECHÓ— y lo que está en pie va
  # en su propio bloque, sólo cuando el período llega a hoy.
  #
  # Lo no vinculado NO se esconde en una sección aparte ni abre el informe con un KPI en grande
  # (decisión de Germán, 12-sep-2026): sale en la misma tabla con su nombre propio y marcado, y
  # arriba va UN AVISO —sólo si hay algo— que nombra qué genéticas salen sin vinculación. Ese
  # aviso, la salvedad del PDF y el candado de «Para presentar» miran LA MISMA lista:
  # `geneticas_sin_vincular_ids`, las genéticas que aparecen en el documento y nada más. Antes el
  # candado miraba todas las del club —archivadas y nunca cultivadas incluidas— y bloqueaba la
  # descarga por una genética que no aparecía en ningún lado.
  #
  # ORIGEN DEL MATERIAL (pedido de Germán): cuántas plantas de cada variedad vinieron de semilla y
  # cuántas de esqueje. Es el dato del mundo del INASE, que es el organismo de las semillas.
  class Inase
    ORIGENES = Plant::ORIGENES   # semilla esqueje

    def initialize(club:, desde:, hasta:)
      @club  = club
      @desde = desde
      @hasta = hasta
    end

    def call
      cosechados = Produccion.new(club: @club, desde: @desde, hasta: @hasta).cosechado_en(@desde, @hasta)
      lotes_cosechados = @club.lotes.where(id: cosechados[:lotes].map { |f| f[:id] })
      lotes_en_pie     = incluye_hoy? ? @club.lotes.where(estado: Lote::CULTIVO_ESTADOS) : @club.lotes.none

      variedades = agrupar(lotes_cosechados, plantas: :cosechadas)
      en_cultivo = agrupar(lotes_en_pie,     plantas: :en_pie)

      geneticas_en_documento = (lotes_cosechados.pluck(:genetica_id) + lotes_en_pie.pluck(:genetica_id)).compact.uniq
      sin_vincular = @club.geneticas.sin_declarar.where(id: geneticas_en_documento).order(:nombre)

      {
        periodo:      { desde: @desde.to_date, hasta: @hasta.to_date, incluye_hoy: incluye_hoy? },
        variedades:   variedades,
        en_cultivo:   en_cultivo,
        # Lo que hay que hacer, con nombre. Vacío = no hay aviso que mostrar.
        sin_vincular: sin_vincular.map { |g| { id: g.id, nombre: g.nombre } },
        geneticas_sin_vincular_ids: sin_vincular.map(&:id),
        kpis: {
          # Las que aparecen en el documento, cosechadas o en pie, contadas una vez.
          variedades:        (variedades + en_cultivo).select { |v| v[:vinculada] }.map { |v| v[:nombre] }.uniq.size,
          sin_vincular:      sin_vincular.size,
          lotes:             variedades.sum { |v| v[:lotes] },
          plantas:           variedades.sum { |v| v[:plantas] },
          gramos:            variedades.sum { |v| v[:gramos] }.round(1),
          plantas_en_pie:    en_cultivo.sum { |v| v[:plantas] },
          lotes_en_pie:      en_cultivo.sum { |v| v[:lotes] },
        },
      }
    end

    private

    def incluye_hoy? = @hasta.to_date >= Time.zone.today

    # Una fila por VARIEDAD ACREDITABLE (`nombre_declarado`): si veinte genéticas propias se declaran
    # contra TROPICANA WFC, son una fila —al organismo le importa cuánto se cultivó de esa variedad,
    # no cómo la llama la organización— y la fila dice cuáles son. Una genética sin vincular es su
    # propia fila, con su nombre propio y `vinculada: false`.
    def agrupar(lotes, plantas:)
      lotes = lotes.includes(genetica: :declarada_como)
      por_lote_origen = plantas_por_origen(lotes, plantas)

      lotes.group_by { |l| l.genetica&.nombre_declarado.presence || l.strain.presence || 'Sin variedad' }
           .map do |nombre, ls|
        gens = ls.filter_map(&:genetica).uniq
        acreditante = gens.find(&:acreditada_inase?)
        origen = ORIGENES.to_h { |o| [o, ls.sum { |l| por_lote_origen.dig(l.id, o).to_i }] }
        # Un lote viejo puede tener el contador cargado y ninguna planta registrada una por una
        # (importado, o de antes del QR por planta): ahí manda el contador, con el origen del lote.
        ls.each do |l|
          next if por_lote_origen[l.id].values.sum.positive?

          contador = (plantas == :cosechadas ? (l.plants_count_cosechadas || l.plants_count) : l.plants_count).to_i
          origen[l.origen.presence_in(ORIGENES) || 'semilla'] += contador
        end
        {
          nombre:    nombre,
          vinculada: gens.any? && gens.all?(&:acreditada_inase?),
          # Quién obtuvo la variedad: es dato del registro del INASE —a diferencia de un «número de
          # registro», que no existe—. Sale de la variedad ACREDITANTE, no de la genética del club.
          criador:   acreditante && (acreditante.declarada_como&.criador || acreditante.criador),
          # Cómo la llama la organización puertas adentro. Se lista sólo cuando difiere del nombre
          # declarado: «acredita: CAT3» debajo de CAT3 no dice nada.
          acredita:  gens.map(&:nombre).reject { |n| n == nombre }.uniq.sort,
          genetica_ids: gens.map(&:id),
          lotes:     ls.size,
          plantas:   origen.values.sum,
          origen:    origen,
          gramos:    ls.sum { |l| l.rendimiento_real_g.to_f }.round(1),
        }
      end.sort_by { |v| [v[:vinculada] ? 0 : 1, -v[:gramos], v[:nombre]] }
    end

    # Plantas por lote y por origen. La planta dice de dónde vino (`plants.origen`) y si no lo
    # dice, lo dice su lote. Para lo cosechado se cuentan las plantas que llegaron al corte (no las
    # descartadas); para lo en pie, las que están en pie.
    def plantas_por_origen(lotes, cual)
      estados = cual == :cosechadas ? Produccion::PLANTA_CORTADA : Lote::CULTIVO_ESTADOS
      Plant.joins(:lote).where(lote_id: lotes.map(&:id), state: estados)
           .group(:lote_id, Arel.sql("COALESCE(plants.origen, lotes.origen, 'semilla')")).count
           .each_with_object(Hash.new { |h, k| h[k] = {} }) { |((lote_id, origen), n), acc| acc[lote_id][origen] = n }
    end
  end
end
