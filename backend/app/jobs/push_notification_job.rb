class PushNotificationJob < ApplicationJob
  queue_as :medium
  sidekiq_options retry: 3

  def perform(subscription_id, title:, body:, url: '/')
    return unless ENV['VAPID_PUBLIC_KEY'].present? && ENV['VAPID_PRIVATE_KEY'].present?

    # Sin tenant a propósito: el job llega por id, sin club, y con `require_tenant` el `find_by`
    # a secas moría con `NoTenantSet` antes de mandar nada — en el worker, en silencio, tres
    # reintentos y a la cola de muertos. Desde que se prendió `require_tenant` (auditoría
    # TEN-01c) NO SALIÓ UN SOLO PUSH; se descubrió el 19-sep-2026 corriéndolo a mano en Render.
    sub = ActsAsTenant.without_tenant { PushSubscription.find_by(id: subscription_id, active: true) }
    return unless sub

    ActsAsTenant.with_tenant(sub.club) { enviar(sub, title, body, url) }
  end

  private

  def enviar(sub, title, body, url)
    WebPush.payload_send(
      # `tag` distinto por aviso: el service worker se lo pasa a `showNotification`, y con el
      # mismo tag el teléfono REEMPLAZA la notificación anterior en vez de sumar una. Dos alertas
      # seguidas dejaban una sola a la vista.
      message:  JSON.generate({ title: title, body: body, url: url, tag: "ce-#{SecureRandom.hex(6)}" }),
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
