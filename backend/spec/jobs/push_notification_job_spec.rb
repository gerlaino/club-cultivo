require 'rails_helper'

# El job llega por id, sin club. Con `require_tenant = true` buscaba la suscripción sin fijar
# tenant y moría con `NoTenantSet` antes de mandar nada — en el worker, en silencio. Desde que
# se prendió `require_tenant` no salió un solo push; se descubrió el 19-sep-2026 corriéndolo a
# mano en Render. Este spec corre el job COMO LO CORRE SIDEKIQ: sin tenant.
RSpec.describe PushNotificationJob, type: :job do
  let(:club)  { create(:club) }
  let(:user)  { create(:user, :admin, club: club) }
  let(:sub) do
    ActsAsTenant.with_tenant(club) do
      PushSubscription.create!(user: user, club: club, endpoint: 'https://push.example/abc',
                               p256dh_key: 'p256', auth_key: 'auth', device_name: 'test', active: true)
    end
  end

  around do |ex|
    viejas = { 'VAPID_PUBLIC_KEY' => ENV['VAPID_PUBLIC_KEY'], 'VAPID_PRIVATE_KEY' => ENV['VAPID_PRIVATE_KEY'] }
    ENV['VAPID_PUBLIC_KEY']  = 'pub'
    ENV['VAPID_PRIVATE_KEY'] = 'priv'
    ex.run
  ensure
    viejas.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end

  # `spec/support/tenant.rb` fija `test_tenant` para todos los ejemplos; acá se saca a
  # propósito, porque Sidekiq no tiene ninguno. OJO: `without_tenant` NO sirve para esto
  # —desactiva el candado y el job viejo pasaba igual—. Sin `test_tenant` y sin `current_tenant`
  # el candado queda puesto y sin tenant, que es exactamente el estado en que corre el worker.
  def como_sidekiq
    viejo = ActsAsTenant.test_tenant
    ActsAsTenant.test_tenant = nil
    ActsAsTenant.with_tenant(nil) { yield }
  ensure
    ActsAsTenant.test_tenant = viejo
  end

  it 'manda el push sin que nadie le fije el tenant' do
    id = sub.id
    expect(WebPush).to receive(:payload_send).with(hash_including(endpoint: 'https://push.example/abc', p256dh: 'p256', auth: 'auth'))

    como_sidekiq do
      expect(ActsAsTenant.current_tenant).to be_nil
      expect { described_class.perform_now(id, title: 'Hola', body: 'Cuerpo', url: '/') }.not_to raise_error
    end
  end

  it 'una suscripción vencida se apaga en vez de reintentarse' do
    id = sub.id
    respuesta = double('respuesta', body: 'gone', code: '410', message: 'Gone', class: Net::HTTPGone)
    allow(WebPush).to receive(:payload_send).and_raise(WebPush::ExpiredSubscription.new(respuesta, 'push.example'))

    como_sidekiq { described_class.perform_now(id, title: 'Hola', body: 'Cuerpo') }

    expect(ActsAsTenant.without_tenant { PushSubscription.find(id).active }).to be false
  end

  it 'sin claves VAPID no intenta mandar' do
    id = sub.id
    ENV.delete('VAPID_PRIVATE_KEY')
    expect(WebPush).not_to receive(:payload_send)

    como_sidekiq { described_class.perform_now(id, title: 'Hola', body: 'Cuerpo') }
  end
end
