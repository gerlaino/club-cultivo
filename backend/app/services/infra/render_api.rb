require 'net/http'
require 'json'

# LO QUE RENDER SABE DE NUESTROS SERVIDORES, leído por su API (https://api-docs.render.com).
#
# Sólo LEE: qué servicios hay y en qué estado, su último deploy, las bases y los Redis, y cuánto CPU
# y memoria usan. No despliega, no reinicia ni cambia nada — para eso está el panel de Render, y un
# botón en nuestro panel sería una forma más de romper producción.
#
# La llave es `RENDER_API_KEY` (Account Settings → API Keys en Render). Vive sólo en el servidor:
# nunca viaja a la pantalla. Sin ella el panel dice «no configurado» y sigue con el resto.
#
# Timeouts cortos: el panel no puede quedarse colgado de Render.
module Infra
  class RenderApi
    BASE = URI('https://api.render.com/v1/').freeze
    class Error < StandardError; end

    def self.configurado? = ENV['RENDER_API_KEY'].present?

    # `transporte` es para los specs: recibe (ruta, query) y devuelve el JSON ya parseado.
    def initialize(transporte: nil)
      @transporte = transporte || method(:http_get)
    end

    def servicios = lista('services', limit: 100).map { |x| x['service'] }
    def postgres  = lista('postgres', limit: 100).map { |x| x['postgres'] }

    # Render renombró Redis a «Key Value»; las cuentas viejas responden en la ruta vieja.
    def key_value
      lista('key-value', limit: 100).map { |x| x['keyValue'] || x['redis'] || x }
    rescue Error
      lista('redis', limit: 100).map { |x| x['redis'] || x }
    end

    def ultimo_deploy(servicio_id)
      lista("services/#{servicio_id}/deploys", limit: 1).first&.dig('deploy')
    end

    # Serie de las últimas `horas`, una muestra por hora. `metrica`: 'cpu' o 'memory'.
    def metrica(metrica, recurso_id, horas: 24)
      fin = Time.current
      series = @transporte.call("metrics/#{metrica}",
                                resource: recurso_id, startTime: (fin - horas.hours).iso8601,
                                endTime: fin.iso8601, resolutionSeconds: 3600)
      Array(series).flat_map { |s| Array(s['values']) }
                   .map { |v| { t: v['timestamp'], v: v['value'].to_f } }
                   .sort_by { |p| p[:t].to_s }
    end

    private

    def lista(ruta, **query) = Array(@transporte.call(ruta, query))

    def http_get(ruta, query)
      uri = URI.join(BASE, ruta)
      uri.query = URI.encode_www_form(query.compact) if query.present?
      req = Net::HTTP::Get.new(uri)
      req['Authorization'] = "Bearer #{ENV.fetch('RENDER_API_KEY')}"
      req['Accept'] = 'application/json'
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 6) { |h| h.request(req) }
      raise Error, "Render respondió #{res.code} en #{ruta}" unless res.is_a?(Net::HTTPSuccess)

      JSON.parse(res.body)
    rescue Error
      raise
    rescue StandardError => e
      raise Error, "No se pudo hablar con Render (#{e.class})"
    end
  end
end
