unless Rails.env.test?
  class Rack::Attack
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
