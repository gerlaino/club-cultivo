redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end

Sidekiq::Cron::Job.load_from_hash(
  'jwt_denylist_cleanup' => {
    'cron'  => '0 * * * *',
    'class' => 'JwtDenylistCleanupJob'
  },
  'reprocann_vencimiento' => {
    'cron'  => '0 8 * * *',
    'class' => 'ReprocannVencimientoJob',
    'description' => 'Genera alertas de vencimiento REPROCANN para todos los clubes'
  }
)
