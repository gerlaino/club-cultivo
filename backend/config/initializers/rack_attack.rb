unless Rails.env.test?
  class Rack::Attack
    # LA IP DE LA PERSONA, NO LA DEL PROXY (29-oct-2026, seguridad tanda 2). Producción está detrás de
    # Cloudflare (Render la usa de borde: `server: cloudflare`, `cf-ray`). Sin esto `req.ip` puede
    # ser la del nodo de Cloudflare, compartida por mucha gente: el freno de login se repartía entre
    # todos los que entran por ese nodo (uno se equivocaba y frenaba a otro) y el atacante cambiaba
    # de nodo. `CF-Connecting-IP` lo pone Cloudflare y pisa lo que mande el cliente; si no viene
    # (local, otro borde), queda `req.ip`.
    def self.ip_cliente(req)
      req.get_header('HTTP_CF_CONNECTING_IP').presence || req.ip
    end

    # El pedido viene en JSON y rack-attack mira antes de que Rails lo parsee.
    def self.cuerpo_json(req)
      cuerpo = JSON.parse(req.body.read)
      cuerpo.is_a?(Hash) ? cuerpo : {}
    rescue JSON::ParserError
      {}
    ensure
      req.body.rewind
    end

    # La respuesta del freno dice qué pasó, en castellano y en JSON: la pantalla de login muestra
    # `error` (antes era «Retry later» en texto plano y el login decía «no pudimos iniciar sesión»).
    self.throttled_responder = lambda do |req|
      espera = (req.env['rack.attack.match_data'] || {})[:period].to_i
      [429, { 'content-type' => 'application/json', 'retry-after' => espera.to_s },
       [{ error: 'Demasiados intentos seguidos. Esperá unos minutos y probá de nuevo.' }.to_json]]
    end
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
        req.params['dispositivo_id'].presence || ip_cliente(req)
      end
    end

    # Sign-in: protección brute-force — 5 intentos/min por IP
    throttle('sign_in/ip', limit: 5, period: 1.minute) do |req|
      ip_cliente(req) if req.path.match?(%r{/api/users/sign_in}) && req.post?
    end
    # Y POR CUENTA (29-oct-2026): probar claves contra UN usuario desde muchas IPs también se frena.
    # 10 en 15 minutos no molesta a quien se equivoca; el costo es que alguien puede trabar la
    # entrada de otro por 15 minutos, que es mejor que dejar probar sin tope.
    throttle('sign_in/cuenta', limit: 10, period: 15.minutes) do |req|
      next unless req.path.match?(%r{/api/users/sign_in}) && req.post?

      usuario = cuerpo_json(req)['user']
      usuario = req.params['user'] unless usuario.is_a?(Hash)
      (usuario.is_a?(Hash) ? usuario['email'] : nil).to_s.strip.downcase.presence
    end

    # Cambiar la contraseña o el mail pide la actual: que no sirva para adivinarla.
    throttle('perfil_clave/ip', limit: 10, period: 10.minutes) do |req|
      ip_cliente(req) if req.path.start_with?('/api/profile') && (req.patch? || req.put?)
    end

    # «Olvidé mi contraseña»: cada pedido manda un mail. Sin freno, una IP puede usar la
    # plataforma para inundar la casilla de alguien o para probar logins.
    throttle('password/ip', limit: 5, period: 10.minutes) do |req|
      ip_cliente(req) if req.path.match?(%r{\A/api/password\z}) && (req.post? || req.put?)
    end

    # Portal del paciente (27-oct-2026). Entrar con DNI: por IP y además por DNI, para que probar
    # claves contra UN paciente desde muchas IPs también se frene. El de la IP deja pasar el segundo
    # pedido de quien es paciente en dos organizaciones (manda lo mismo con la que eligió).
    throttle('portal_sesion/ip', limit: 8, period: 1.minute) do |req|
      ip_cliente(req) if req.path == '/api/portal_acceso/sesion' && req.post?
    end
    throttle('portal_sesion/dni', limit: 10, period: 10.minutes) do |req|
      next unless req.path == '/api/portal_acceso/sesion' && req.post?

      (req.params['dni'] || cuerpo_json(req)['dni']).to_s.gsub(/\D/, '').presence
    end
    # Activar un link pide el DNI: además del freno por IP, el link se cae solo a los 5 errores.
    throttle('portal_activar/ip', limit: 10, period: 10.minutes) do |req|
      ip_cliente(req) if req.path.match?(%r{\A/api/portal_acceso/links/[^/]+/activar\z}) && req.post?
    end
    throttle('portal_link/ip', limit: 30, period: 1.minute) do |req|
      ip_cliente(req) if req.path.start_with?('/api/portal_acceso/links/') && req.get?
    end
    # La cara de la puerta de una organización: que no sirva para recorrer slugs.
    throttle('portal_organizacion/ip', limit: 30, period: 1.minute) do |req|
      ip_cliente(req) if req.path.start_with?('/api/portal_acceso/organizaciones/') && req.get?
    end
    # «Me olvidé la clave» manda un mail: mismo criterio que el del equipo.
    throttle('portal_recuperar/ip', limit: 5, period: 10.minutes) do |req|
      ip_cliente(req) if req.path == '/api/portal_acceso/recuperar' && req.post?
    end

    # Autoregistro: cada alta crea una organización entera. 3 por hora por IP alcanza para una
    # persona que se equivocó; frena a quien quiere llenar la base de cuentas basura.
    throttle('registro/ip', limit: 3, period: 1.hour) do |req|
      ip_cliente(req) if req.path == '/api/public/registro' && req.post?
    end
    # Reenviar la confirmación manda un mail: mismo criterio que «olvidé mi contraseña».
    throttle('registro_reenviar/ip', limit: 3, period: 10.minutes) do |req|
      ip_cliente(req) if req.path == '/api/public/registro/reenviar' && req.post?
    end
    # El formulario de contacto avisa por push y por mail a la plataforma.
    throttle('contacto/ip', limit: 5, period: 1.hour) do |req|
      ip_cliente(req) if req.path == '/api/public/contacto' && req.post?
    end

    # Gate por DNI del pasaporte de dispensa: evita probar DNIs a lo bruto.
    throttle('dispensa_ver/ip', limit: 10, period: 1.minute) do |req|
      ip_cliente(req) if req.path.match?(%r{\A/api/d/[^/]+/ver\z}) && req.post?
    end

    # Reseña del paciente (también gateada por DNI): mismo espíritu anti-fuerza-bruta.
    throttle('dispensa_resena/ip', limit: 15, period: 1.minute) do |req|
      ip_cliente(req) if req.path.match?(%r{\A/api/d/[^/]+/resena\z}) && req.post?
    end

    # Asistente IA: 30 req/min por IP (complementa el rate limit interno por tier)
    throttle('asistente/ip', limit: 30, period: 1.minute) do |req|
      ip_cliente(req) if req.path.start_with?('/api/asistente')
    end

    # Protección genérica por IP
    throttle('req/ip', limit: 300, period: 5.minutes) do |req|
      ip_cliente(req) unless req.path.start_with?('/assets')
    end
  end
end
