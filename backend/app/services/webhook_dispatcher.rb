class WebhookDispatcher
  def self.dispatch(club, event, payload)
    return if club.personal? # el autocultivo no tiene integraciones (ver `WebhooksController`)

    club.webhooks.activos.select { |w| w.escucha?(event) }.each do |webhook|
      OutgoingWebhookJob.perform_later(webhook.id, event, payload)
    end
  end
end
