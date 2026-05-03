unless Rails.env.test?
  class Rack::Attack
    # Limit webhook ingestion to 1 req/s per dispositivo_id to prevent flooding
    throttle('webhooks/dispositivo', limit: 60, period: 60) do |req|
      if req.path.match?(%r{/webhooks/lecturas})
        req.params['dispositivo_id']
      end
    end

    # Generic IP-based protection
    throttle('req/ip', limit: 300, period: 5.minutes) do |req|
      req.ip unless req.path.start_with?('/assets')
    end
  end
end
