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
    def registrar(club:, funcion:, modelo:, user: nil, input_tokens: 0, output_tokens: 0,
                  ok: true, error_clase: nil)
      return if club.nil?

      IaLlamada.create!(
        club: club, user: user, funcion: funcion.to_s, modelo: modelo.to_s,
        input_tokens: input_tokens.to_i, output_tokens: output_tokens.to_i,
        costo_usd: IaLlamada.costo_de(modelo: modelo.to_s, input_tokens: input_tokens,
                                      output_tokens: output_tokens),
        ok: ok, error_clase: error_clase
      )
    rescue StandardError => e
      Rails.logger.error("[IA] no se pudo registrar el uso de club##{club&.id}: #{e.class} #{e.message}")
      nil
    end

    # Extrae los tokens de la respuesta de la API de Anthropic. El body trae
    # `usage: { input_tokens:, output_tokens: }`; si cambiara de forma, devolvemos ceros en vez
    # de romper la llamada que ya salió bien.
    def tokens_de(body)
      u = body.is_a?(Hash) ? (body['usage'] || body[:usage]) : nil
      return [0, 0] unless u.is_a?(Hash)

      [(u['input_tokens'] || u[:input_tokens]).to_i, (u['output_tokens'] || u[:output_tokens]).to_i]
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
      base = IaLlamada.where(club_id: club.id).del_mes(fecha)
      {
        llamadas:   base.count,
        tope:       club.ia_limite_mes,
        tokens:     base.sum(:input_tokens) + base.sum(:output_tokens),
        costo_usd:  base.sum(:costo_usd).to_f.round(2),
        por_funcion: base.group(:funcion).count,
      }
    end
  end
end
