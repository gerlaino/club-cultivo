class PushNotificationJob < ApplicationJob
  queue_as :medium
  sidekiq_options retry: 3

  def perform(subscription_id, title:, body:, url: '/')
    return unless ENV['VAPID_PUBLIC_KEY'].present? && ENV['VAPID_PRIVATE_KEY'].present?

    sub = PushSubscription.find_by(id: subscription_id, active: true)
    return unless sub

    WebPush.payload_send(
      message:  JSON.generate({ title: title, body: body, url: url }),
      endpoint: sub.endpoint,
      p256dh:   sub.p256dh_key,
      auth:     sub.auth_key,
      vapid: {
        subject:     "mailto:#{ENV.fetch('VAPID_EMAIL', 'admin@clubcultivo.ar')}",
        public_key:  ENV['VAPID_PUBLIC_KEY'],
        private_key: ENV['VAPID_PRIVATE_KEY'],
      },
      ttl: 60 * 60 * 24
    )
  rescue WebPush::InvalidSubscription, WebPush::ExpiredSubscription
    sub&.update_column(:active, false)
  rescue => e
    Rails.logger.error("[PushNotificationJob] #{e.class}: #{e.message}")
    raise
  end
end
