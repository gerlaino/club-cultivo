module Ia
  # Registro y control de consumo de IA.
  #
  # Antes esto vivía repartido: el rate limit era una función privada del controller del
  # asistente (Redis, TTL de una hora) y el consumo no se guardaba en ningún lado salvo los
  # tokens del análisis de lote. Tres consecuencias, las tres arregladas acá:
  #
  #   1. El tope contaba POR USUARIO (`asistente:user:{id}:{hora}`) mientras el límite es del
  #      club: cinco usuarios en tier básico daban 100 llamadas/hora reales, no 20.
  #   2. Sólo lo chequeaba el asistente. Análisis de lote, plan de trabajo e importación CSV
  #      eran ilimitados.
  #   3. `rescue false`: si Redis se caía, el límite dejaba de aplicar en silencio.
  module Uso
    module_function

    # Guarda la llamada. NUNCA levanta: si falla el registro, la funcionalidad tiene que seguir
    # andando — perder una fila de consumo es malo, romperle el asistente al cultivador es peor.
    def registrar(club:, funcion:, modelo:, user: nil, tokens: {}, ok: true, error_clase: nil)
      return if club.nil?

      t = TOKENS_VACIOS.merge(tokens || {})

      IaLlamada.create!(
        club: club, user: user, funcion: funcion.to_s, modelo: modelo.to_s,
        input_tokens: t[:input], output_tokens: t[:output],
        cache_creation_tokens: t[:cache_creation], cache_read_tokens: t[:cache_read],
        costo_usd: IaLlamada.costo_de(
          modelo: modelo.to_s, input_tokens: t[:input], output_tokens: t[:output],
          cache_creation_tokens: t[:cache_creation], cache_read_tokens: t[:cache_read]
        ),
        ok: ok, error_clase: error_clase
      )
    rescue StandardError => e
      Rails.logger.error("[IA] no se pudo registrar el uso de club##{club&.id}: #{e.class} #{e.message}")
      nil
    end

    TOKENS_VACIOS = { input: 0, output: 0, cache_creation: 0, cache_read: 0 }.freeze

    # Extrae los tokens del `usage` de la respuesta. Con caché de prompt la entrada viene
    # partida en tres —a precio lleno, escrita en caché y leída de caché—, y cada una cuesta
    # distinto. Si el body cambiara de forma devolvemos ceros en vez de romper una llamada que
    # ya salió bien.
    def tokens_de(body)
      u = body.is_a?(Hash) ? (body['usage'] || body[:usage]) : nil
      return TOKENS_VACIOS.dup unless u.is_a?(Hash)

      leer = ->(k) { (u[k.to_s] || u[k.to_sym]).to_i }
      {
        input:          leer.call(:input_tokens),
        output:         leer.call(:output_tokens),
        cache_creation: leer.call(:cache_creation_input_tokens),
        cache_read:     leer.call(:cache_read_input_tokens),
      }
    end

    # ¿Se pasó del tope? Devuelve nil si puede seguir, o el mensaje a mostrar si no.
    #
    # El mensual manda porque es el que se vende; el horario queda como freno de ráfaga. Se
    # chequea primero el mensual: si consumiste el mes, el mensaje correcto es ese y no
    # "esperá unos minutos", que sugeriría que se destraba solo.
    def limite_alcanzado(club, user)
      return nil if club.nil?

      usadas_mes = IaLlamada.where(club_id: club.id).del_mes.count
      tope_mes   = club.ia_limite_mes.to_i
      if tope_mes.positive? && usadas_mes >= tope_mes
        return "La organización llegó al tope de #{tope_mes} consultas de IA de este mes. " \
               'Se renueva el día 1; para ampliarlo, escribinos.'
      end

      excedio_hora?(club, user) ? 'Muchas consultas seguidas. Probá de nuevo en unos minutos.' : nil
    end

    # Ráfaga: por CLUB y por hora. Si Redis no responde no se puede afirmar que se excedió, así
    # que se deja pasar — pero ruidoso en el log, no en silencio. El tope mensual, que es el que
    # protege la facturación, se calcula contra la base y no depende de Redis.
    def excedio_hora?(club, _user)
      limite = club.ia_limite_efectivo.to_i
      return false unless limite.positive?

      key   = "ia:club:#{club.id}:#{Time.current.strftime('%Y%m%d%H')}"
      redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
      count = redis.incr(key)
      redis.expire(key, 3600) if count == 1
      count > limite
    rescue StandardError => e
      Rails.logger.warn("[IA] rate limit por hora no disponible (club##{club.id}): #{e.class} #{e.message}")
      false
    end

    # Resumen para el panel: cuánto va del mes y cuánto costó.
    def resumen_mes(club, fecha = Time.zone.today)
      base    = IaLlamada.where(club_id: club.id).del_mes(fecha)
      leidos  = base.sum(:cache_read_tokens)
      entrada = base.sum(:input_tokens) + base.sum(:cache_creation_tokens) + leidos

      {
        llamadas:   base.count,
        tope:       club.ia_limite_mes,
        tokens:     entrada + base.sum(:output_tokens),
        costo_usd:  base.sum(:costo_usd).to_f.round(2),
        # Qué porcentaje de la entrada se sirvió de caché. Si esto es 0 con el asistente en uso,
        # el caché no está funcionando y hay que buscar qué invalida el prefijo.
        cache_hit:  entrada.positive? ? (leidos * 100.0 / entrada).round(1) : 0.0,
        por_funcion: base.group(:funcion).count,
      }
    end
  end
end
