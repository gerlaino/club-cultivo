class OutgoingWebhookJob < ApplicationJob
  queue_as :medium
  sidekiq_options retry: 4, backtrace: true

  sidekiq_retry_in do |count|
    [30, 120, 600, 3600][count] || 3600
  end

  def perform(webhook_id, event, payload)
    webhook = Webhook.find_by(id: webhook_id, active: true)
    return unless webhook

    OutgoingWebhookService.new(webhook, event, payload).call
  end
end
