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
    http     = Net::HTTP.new(uri.host, uri.port)
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
        error_message: "HTTP #{response.code}: #{response.body.to_s.truncate(500)}"
      )
      raise "Webhook responded with #{response.code}"
    end

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
