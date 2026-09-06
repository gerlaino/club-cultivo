module Mostradores
  # ¿LA MERMA DE ESTE MOSTRADOR ESTÁ COMO SIEMPRE, O CAMBIÓ ALGO?
  #
  # Un porcentaje solo no dice nada: 3% puede ser normal fraccionando flor y un escándalo en
  # aceite. Lo que importa no es el número sino que CAMBIÓ respecto del patrón de ESA
  # organización — cada una es la suya.
  #
  # Esta regla vivía adentro de `MermaMostradorJob`, que le manda un mail al admin diciendo "acá
  # cambió algo, andá a mirar". El admin entraba a mirar y la solapa no le decía nada de eso: el
  # criterio existía en un lado y la pantalla en otro. Ahora los dos preguntan acá.
  #
  # NO ACUSA A NADIE. La merma es inevitable y se cuenta para saber cuánta hay y dónde, no para
  # señalar a alguien. El texto que sale de esto tiene que sonar así.
  class Veredicto
    # Hace falta historia para que "cambió" signifique algo: con dos turnos, cualquier diferencia
    # parece un salto.
    TURNOS_MINIMOS = 8
    # Y un piso de volumen: 2 g sobre 10 dispensados es 20% y no dice nada.
    GRAMOS_MINIMOS = 200
    # Cuánto tiene que empeorar respecto de su propio patrón para que valga interrumpir a alguien.
    FACTOR = 2.0

    # `dias` de la ventana reciente y `previos` de la que hace de patrón. Los valores por defecto
    # son los que usa el aviso automático: última semana contra las ocho anteriores.
    def self.call(**kwargs) = new(**kwargs).call

    def initialize(mostrador:, hasta: nil, dias: 7, previos: 56)
      @mostradores = Array(mostrador)
      @hasta       = hasta || Time.zone.today
      @dias        = dias
      @previos     = previos
    end

    # Siempre devuelve algo: la pantalla tiene que poder decir "todavía no hay con qué comparar"
    # en vez de quedarse en blanco, que se lee como que está todo bien.
    #
    #   estado  → :subio · :normal · :poco_volumen · :sin_historia · :sin_datos
    #   motor   → el producto que la está moviendo, cuando subió. Sin eso, "subió" manda a mirar
    #             tres tablas para encontrar el renglón que ya sabemos cuál es.
    def call
      return sin(:sin_datos) if reciente[:turnos].zero?
      return sin(:poco_volumen) if reciente[:dispensado] < GRAMOS_MINIMOS
      return sin(:sin_historia) if previo[:turnos] < TURNOS_MINIMOS || previo[:pct].nil?
      return sin(:normal) if reciente[:pct].nil? || reciente[:pct] <= previo[:pct] * FACTOR

      base.merge(estado: 'subio', motor: motor)
    end

    private

    def sin(estado) = base.merge(estado: estado.to_s, motor: nil)

    def base
      {
        desde:        (@hasta - (@dias - 1)),
        hasta:        @hasta,
        pct:          reciente[:pct],
        pct_previo:   previo[:pct],
        dispensado:   reciente[:dispensado],
        faltante_ars: reciente[:ars],
        turnos:       reciente[:turnos],
        turnos_previos: previo[:turnos],
        # Cuántas semanas de patrón hay atrás. La frase de la pantalla lo dice: "contra las
        # últimas ocho semanas" es una afirmación, y tiene que ser cierta.
        semanas_previas: (@previos / 7.0).round,
        factor:       FACTOR,
      }
    end

    def reciente = @reciente ||= medir(@hasta - (@dias - 1), @hasta)
    def previo   = @previo   ||= medir(@hasta - @previos, @hasta - @dias)

    def medir(desde, hasta)
      r = Merma.call(mostrador: @mostradores, desde: desde, hasta: hasta, veredicto: false)[:resumen]
      { pct: r[:merma_pct], dispensado: r[:dispensado].to_f, turnos: r[:turnos].to_i,
        ars: r[:faltante_ars].to_f }
    end

    # El producto que más aporta a la merma de la semana, en PLATA. Se elige por plata y no por
    # porcentaje a propósito: acá la pregunta ya no es "¿cuál se pierde proporcionalmente más?"
    # sino "¿qué estoy mirando primero?", y eso lo contesta lo que más cuesta.
    def motor
      lista = Merma.call(mostrador: @mostradores, desde: @hasta - (@dias - 1), hasta: @hasta,
                         veredicto: false)[:por_producto]
      p = lista.select { |x| x[:faltante_ars].to_f.positive? }.max_by { |x| x[:faltante_ars].to_f }
      return nil if p.nil?

      { producto: p[:producto], pct: p[:merma_pct], faltante: p[:faltante],
        unidad: p[:unidad], faltante_ars: p[:faltante_ars] }
    end
  end
end
