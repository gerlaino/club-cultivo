require 'net/http'

module Pagos
  # El cliente HTTP de Mercado Pago (suscripciones). Lo mínimo: crear, leer y cambiar un
  # `preapproval`, y leer un `authorized_payment` (cada cobro mensual).
  #
  # Credenciales por entorno: `MP_ACCESS_TOKEN` (de la cuenta que cobra) y `MP_WEBHOOK_SECRET` (la
  # clave secreta de las notificaciones, en «Tus integraciones → Webhooks»). Sin token no se
  # llama a nadie: `configurado?` lo dice y la pantalla no ofrece cobrar.
  class MercadoPago
    class Error < StandardError; end

    BASE = 'https://api.mercadopago.com'.freeze

    def self.configurado? = ENV['MP_ACCESS_TOKEN'].present?

    def crear_preapproval(cuerpo)       = pedir(:post, '/preapproval', cuerpo)
    def preapproval(id)                 = pedir(:get, "/preapproval/#{id}")
    def actualizar_preapproval(id, c)   = pedir(:put, "/preapproval/#{id}", c)
    def authorized_payment(id)          = pedir(:get, "/authorized_payments/#{id}")

    # La firma del aviso (`x-signature: ts=…,v1=…`): HMAC-SHA256 del manifiesto
    # `id:<data.id>;request-id:<x-request-id>;ts:<ts>;` con la clave secreta. Sin clave cargada no
    # se acepta ningún aviso: un webhook sin verificar dejaría a cualquiera activarse el plan.
    def self.firma_valida?(firma:, request_id:, data_id:)
      secreto = ENV['MP_WEBHOOK_SECRET'].presence
      return false if secreto.nil? || firma.blank?

      partes = firma.split(',').to_h { |p| p.strip.split('=', 2) }
      ts, v1 = partes['ts'], partes['v1']
      return false if ts.blank? || v1.blank?

      manifiesto = +"id:#{data_id.to_s.downcase};"
      manifiesto << "request-id:#{request_id};" if request_id.present?
      manifiesto << "ts:#{ts};"
      esperado = OpenSSL::HMAC.hexdigest('SHA256', secreto, manifiesto)
      ActiveSupport::SecurityUtils.secure_compare(esperado, v1)
    end

    private

    def pedir(metodo, ruta, cuerpo = nil)
      token = ENV['MP_ACCESS_TOKEN'].presence or raise Error, 'Mercado Pago no está configurado (falta MP_ACCESS_TOKEN).'
      uri  = URI("#{BASE}#{ruta}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 20
      req = { get: Net::HTTP::Get, post: Net::HTTP::Post, put: Net::HTTP::Put }.fetch(metodo).new(uri)
      req['Authorization'] = "Bearer #{token}"
      req['Content-Type']  = 'application/json'
      req.body = cuerpo.to_json if cuerpo
      res  = http.request(req)
      json = JSON.parse(res.body.presence || '{}')
      return json if res.code.to_i.between?(200, 299)

      raise Error, "Mercado Pago respondió #{res.code}: #{json['message'] || json['error'] || res.body.to_s.first(200)}"
    rescue JSON::ParserError
      raise Error, "Mercado Pago respondió algo que no se entiende (#{res&.code})."
    end
  end
end
