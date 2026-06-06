class WebhookDispatcher
  def self.dispatch(club, event, payload)
    club.webhooks.activos.select { |w| w.escucha?(event) }.each do |webhook|
      OutgoingWebhookJob.perform_later(webhook.id, event, payload)
    end
  end
end
