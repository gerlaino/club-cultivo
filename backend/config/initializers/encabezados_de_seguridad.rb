# LO QUE EL NAVEGADOR TIENE QUE SABER DE CADA RESPUESTA (HDR-01, 29-oct-2026).
#
# La app llega por dos caminos que no comparten encabezados: la API (Rails pone los suyos) y la
# cáscara del frontend que sirve `ActionDispatch::Static` desde `public/`, que no lleva ninguno.
# En producción no llegaba ni uno: cualquier página podía meter la app adentro de un iframe
# invisible y hacer que alguien tocara «Dispensar» o «Confirmar» creyendo que tocaba otra cosa.
# Este middleware los pone en TODO lo que sale, si la respuesta no trae ya el suyo.
#
# - `frame-ancestors 'self'` y `X-Frame-Options` (el viejo, para navegadores viejos): sólo la
#   propia app puede mostrarse dentro de sí misma.
# - `object-src 'none'` y `base-uri 'self'`: sin plugins ni `<base>` que cambie a dónde apuntan los
#   links. Todavía NO hay `script-src`: la app carga Sentry y fuentes de afuera, y una lista mal
#   armada deja la pantalla en blanco. Va aparte, primero en modo «sólo avisar».
# - `nosniff`: un archivo subido se interpreta como lo que dice ser, nunca como un script.
# - `Referrer-Policy`: al salir a otro sitio no viaja la dirección completa (llevaría el token de
#   un link de acceso o el id de un paciente).
# - `Permissions-Policy`: cámara (escanear QR) y micrófono (dictado) sólo para la propia app.
class EncabezadosDeSeguridad
  ENCABEZADOS = {
    'content-security-policy' => "frame-ancestors 'self'; object-src 'none'; base-uri 'self'",
    'x-frame-options'         => 'SAMEORIGIN',
    'x-content-type-options'  => 'nosniff',
    'referrer-policy'         => 'strict-origin-when-cross-origin',
    'permissions-policy'      => 'camera=(self), microphone=(self), geolocation=(self), payment=(), usb=()'
  }.freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    ENCABEZADOS.each do |nombre, valor|
      headers[nombre] = valor unless headers[nombre].present? || headers[nombre.split('-').map(&:capitalize).join('-')].present?
    end
    [status, headers, body]
  end
end

Rails.application.config.middleware.insert_before ActionDispatch::Static, EncabezadosDeSeguridad
