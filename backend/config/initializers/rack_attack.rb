unless Rails.env.test?
  class Rack::Attack
    # EN DESARROLLO, LA MÁQUINA PROPIA NO SE LIMITA.
    #
    # El tope de sign-in son 5 por minuto y la suite de punta a punta hace siete logins: corriéndola
    # entera, el sexto recibía 429 y la prueba fallaba en un lugar que no tenía nada que ver —una
    # pantalla que "no cargaba"—. Una suite que falla por el ambiente y no por el código enseña a
    # ignorar los rojos, que es exactamente lo que estas pruebas existen para evitar.
    #
    # Sólo en desarrollo y sólo desde la máquina local: en producción el candado no se toca, que es
    # donde protege de la fuerza bruta de verdad.
    if Rails.env.development?
      safelist('dev/local') { |req| %w[127.0.0.1 ::1].include?(req.ip) }
    end

    # Webhooks IoT: 60 req/min por dispositivo_id; si falta el id, cae al IP
    throttle('webhooks/dispositivo', limit: 60, period: 60) do |req|
      if req.path.match?(%r{/webhooks/lecturas})
        req.params['dispositivo_id'].presence || req.ip
      end
    end

    # Sign-in: protección brute-force — 5 intentos/min por IP
    throttle('sign_in/ip', limit: 5, period: 1.minute) do |req|
      req.ip if req.path.match?(%r{/api/users/sign_in}) && req.post?
    end

    # Gate por DNI del pasaporte de dispensa: evita probar DNIs a lo bruto.
    throttle('dispensa_ver/ip', limit: 10, period: 1.minute) do |req|
      req.ip if req.path.match?(%r{\A/api/d/[^/]+/ver\z}) && req.post?
    end

    # Reseña del paciente (también gateada por DNI): mismo espíritu anti-fuerza-bruta.
    throttle('dispensa_resena/ip', limit: 15, period: 1.minute) do |req|
      req.ip if req.path.match?(%r{\A/api/d/[^/]+/resena\z}) && req.post?
    end

    # Asistente IA: 30 req/min por IP (complementa el rate limit interno por tier)
    throttle('asistente/ip', limit: 30, period: 1.minute) do |req|
      req.ip if req.path.start_with?('/api/asistente')
    end

    # Protección genérica por IP
    throttle('req/ip', limit: 300, period: 5.minutes) do |req|
      req.ip unless req.path.start_with?('/assets')
    end
  end
end
