require 'net/http'
require 'openssl'

class OutgoingWebhookService
  TIMEOUT = 10

  def initialize(webhook, event, payload)
    @webhook  = webhook
    @event    = event
    @payload  = payload
  end

  def call
    delivery = @webhook.webhook_deliveries.create!(
      event:      @event,
      payload_json: body,
      status:     'pending',
      attempts:   0
    )

    t0 = Time.current
    delivery.update!(attempts: 1, last_attempted_at: t0)

    uri      = URI.parse(@webhook.url)
    # Se conecta a la IP ya validada (`Seguridad::DestinoPublico`), no a la que resuelva
    # Net::HTTP: el host sigue yendo en el Host y en el SNI del TLS.
    ip       = Seguridad::DestinoPublico.ip!(uri.host)
    http     = Net::HTTP.new(uri.host, uri.port)
    http.ipaddr         = ip
    http.use_ssl        = uri.scheme == 'https'
    http.open_timeout   = TIMEOUT
    http.read_timeout   = TIMEOUT

    request = Net::HTTP::Post.new(uri.request_uri)
    request['Content-Type']  = 'application/json'
    request['X-CE-Event']    = @event
    request['X-CE-Signature'] = signature
    request['User-Agent']    = 'CultivoEspacial-Webhooks/1.0'
    request.body = body

    response = http.request(request)
    duration = ((Time.current - t0) * 1000).to_i

    if response.code.to_i.between?(200, 299)
      delivery.update!(status: 'success', http_code: response.code.to_i, duration_ms: duration)
    else
      delivery.update!(
        status:        'failed',
        http_code:     response.code.to_i,
        duration_ms:   duration,
        # Sólo el código: el cuerpo de la respuesta no se guarda ni se muestra. Guardarlo
        # convertía al webhook en una forma de LEER lo que contesta cualquier servidor.
        error_message: "HTTP #{response.code}"
      )
      raise "Webhook responded with #{response.code}"
    end

  rescue Seguridad::DestinoPublico::Rechazado => e
    # No se reintenta: el destino no va a dejar de ser privado.
    delivery&.update!(status: 'failed', error_message: e.message,
                      duration_ms: ((Time.current - t0) * 1000).to_i)
    nil
  rescue => e
    delivery&.update!(
      status:        'failed',
      error_message: e.message.truncate(500),
      duration_ms:   ((Time.current - t0) * 1000).to_i
    )
    raise
  end

  private

  def body
    @body ||= JSON.generate({
      event:     @event,
      timestamp: Time.current.iso8601,
      data:      @payload,
    })
  end

  def signature
    digest = OpenSSL::HMAC.hexdigest('SHA256', @webhook.secret, body)
    "sha256=#{digest}"
  end
end
