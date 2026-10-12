# GUÍA DE NUTRIENTES del autocultivo (11-oct-2026, Germán): una REFERENCIA general, no un plan ni
# una receta. Dice qué usa la planta en cada fase —por nutriente, nunca por marca— y en qué rangos
# de EC y pH conviene moverse. La persona la lee y, si quiere, la aplica: aplicar es copiar esos
# rangos a SUS valores de alerta (`SetpointFase`), que después edita. No crea tareas, no toca
# recetas ni insumos.
#
# Por qué así y no un calendario de productos: no hay una receta demostrada que sirva para todos.
# Lo estudiado (Universidad de Guelph, en sustrato inerte y con una genética por ensayo) son los
# nutrientes que la planta aprovecha mejor en cada fase; cada genética, sustrato y ambiente es
# distinto. Ofrecer «tal marca, tantos ml» nos haría responsables de una cosecha que depende de
# cosas que no vemos. Por eso el aviso va siempre, en la pantalla y acá.
#
# Los rangos de EC y pH son los MISMOS que usan las alertas cuando la persona no cargó los suyos
# (`AlertaDetectorService::RANGOS`): una sola fuente, así la guía y el aviso nunca dicen distinto.
module Nutricion
  class Guia
    FASES = %w[enraizado vegetativo floracion].freeze
    TIPOS = %w[ph ec].freeze
    DIAS_COMPARACION = 14

    AVISO = 'Es una referencia general basada en estudios hechos en sustrato inerte, con pocas ' \
            'genéticas. Cada genética, sustrato y ambiente es distinto: ajustá según cómo responden ' \
            'tus plantas. No reemplaza tu criterio ni las indicaciones de cada producto.'.freeze

    TEXTOS = {
      'enraizado' => {
        titulo: 'Germinación y enraizado',
        predomina: 'Casi nada',
        detalle: 'Sin raíz que absorba, la planta vive de la semilla o del esqueje. Agua sola o una ' \
                 'solución muy suave: un exceso de sales quema más de lo que ayuda.',
      },
      'vegetativo' => {
        titulo: 'Vegetativo',
        predomina: 'Nitrógeno (N)',
        detalle: 'El nitrógeno arma hojas y tallos; el fósforo y el potasio acompañan en menor ' \
                 'medida. Calcio y magnesio hacen falta todo el ciclo (en coco o con agua de ósmosis ' \
                 'suele haber que sumarlos). En los estudios, lo que mejor funcionó en vegetativo ' \
                 'rondó 160–200 mg/L de N, 30 de fósforo y 60 de potasio.',
      },
      'floracion' => {
        titulo: 'Floración',
        predomina: 'Fósforo (P) y potasio (K), sin dejar el nitrógeno',
        detalle: 'Las flores piden más fósforo: en los estudios, el óptimo rondó 60 mg/L, el doble ' \
                 'que en vegetativo. El nitrógeno siguió importando (cerca de 190 mg/L) y el ' \
                 'potasio no cambió el rendimiento en el rango probado. Las tablas de las marcas ' \
                 'suelen bajar el nitrógeno y subir fósforo y potasio: es una práctica común, no ' \
                 'una regla demostrada.',
      },
    }.freeze

    SUELO_VIVO = 'En suelo vivo no se persigue una EC: se alimenta el suelo (compost, humus, top ' \
                 'dress) y la vida del suelo entrega los nutrientes. Los rangos de EC no aplican.'.freeze
    PH_TIERRA  = 'Los rangos de pH son para coco, sustrato inerte o hidroponía. En tierra se trabaja ' \
                 'algo más alto: 6,2 a 6,8.'.freeze

    FUENTES = [
      { titulo: 'Kpai et al. (2024) · Nutrición mineral en vegetativo', url: 'https://www.frontiersin.org/articles/10.3389/fpls.2024.1501484/full' },
      { titulo: 'Bevan, Jones y Zheng (2021) · N, P y K en floración', url: 'https://www.frontiersin.org/journals/plant-science/articles/10.3389/fpls.2021.764103' },
      { titulo: 'Saloner y Bernstein (2020) · Nitrógeno en cannabis medicinal', url: 'https://pmc.ncbi.nlm.nih.gov/articles/PMC7704455' },
    ].freeze

    def initialize(club)
      @club = club
    end

    def to_h
      {
        aviso: AVISO, suelo_vivo: SUELO_VIVO, ph_tierra: PH_TIERRA, fuentes: FUENTES,
        dias_comparacion: DIAS_COMPARACION,
        aplicada: aplicada?,
        fases: FASES.map { |f| fase_h(f) },
      }
    end

    # Copia los rangos de la guía a los valores de alerta generales de la persona (sin genética).
    # Los de una genética puntual no se tocan: los cargó a propósito.
    def aplicar!
      SetpointFase.transaction do
        FASES.each do |fase|
          TIPOS.each do |tipo|
            rango = referencia(fase, tipo)
            sp = SetpointFase.find_or_initialize_by(club_id: @club.id, fase: fase, tipo_lectura: tipo, genetica_id: nil)
            sp.update!(valor_min: rango.min, valor_max: rango.max)
          end
        end
      end
      to_h
    end

    private

    def referencia(fase, tipo) = AlertaDetectorService::RANGOS.dig(fase, tipo.to_sym)

    def propios
      @propios ||= SetpointFase.where(club_id: @club.id, genetica_id: nil, fase: FASES, tipo_lectura: TIPOS)
                               .where.not(valor_min: nil).where.not(valor_max: nil)
                               .index_by { |s| [s.fase, s.tipo_lectura] }
    end

    def aplicada?
      FASES.all? do |f|
        TIPOS.all? do |t|
          sp = propios[[f, t]]
          r = referencia(f, t)
          sp && sp.valor_min.to_f == r.min.to_f && sp.valor_max.to_f == r.max.to_f
        end
      end
    end

    def rango_h(r) = r && { min: r.min.to_f, max: r.max.to_f }

    def fase_h(fase)
      tuyos = TIPOS.to_h { |t| sp = propios[[fase, t]]; [t, sp && { min: sp.valor_min.to_f, max: sp.valor_max.to_f }] }
      TEXTOS[fase].merge(
        fase: fase,
        ph: rango_h(referencia(fase, 'ph')), ec: rango_h(referencia(fase, 'ec')),
        tus_rangos: tuyos,
        comparacion: comparar(fase, tuyos),
      )
    end

    # Los riegos y registros de las últimas dos semanas de las plantas que HOY están en esa fase,
    # contra el rango que les aplica (el propio si lo cargó, si no el de la guía). Sólo cuenta; no
    # juzga una planta por un registro.
    def comparar(fase, tuyos)
      regs = RegistroAmbiental.joins(:lote)
                              .where(lotes: { club_id: @club.id, estado: fase })
                              .where('registros_ambientales.registrado_en >= ?', DIAS_COMPARACION.days.ago)
                              .pluck(:ph, :ec)
      TIPOS.each_with_index.to_h do |tipo, i|
        valores = regs.filter_map { |r| r[i]&.to_f }
        rango = tuyos[tipo] ? (tuyos[tipo][:min]..tuyos[tipo][:max]) : referencia(fase, tipo)
        [tipo, { registros: valores.size, fuera: valores.count { |v| !rango.cover?(v) } }]
      end
    end
  end
end
