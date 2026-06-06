redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }

  config.on(:startup) do
    Sidekiq::Cron::Job.load_from_hash(
      'jwt_denylist_cleanup' => {
        'cron'  => '0 * * * *',
        'class' => 'JwtDenylistCleanupJob'
      },
      'reprocann_vencimiento' => {
        'cron'  => '0 8 * * *',
        'class' => 'ReprocannVencimientoJob',
        'description' => 'Genera alertas de vencimiento REPROCANN para todos los clubes'
      },
      'indicacion_vencimiento' => {
        'cron'  => '0 8 * * *',
        'class' => 'IndicacionVencimientoJob',
        'description' => 'Genera alertas de vencimiento de indicaciones médicas para todos los clubes'
      },
      'stock_bajo' => {
        'cron'  => '0 9 * * *',
        'class' => 'StockBajoJob',
        'description' => 'Genera alertas de stock bajo (< 50g) para todos los clubes'
      },
      'detectar_alertas_cultivo' => {
        'cron'  => '0 7 * * *',
        'class' => 'DetectarAlertasJob',
        'description' => 'Detecta anomalías de cultivo: registros vencidos, pH/EC fuera de rango, cosecha pendiente, tareas vencidas'
      },
      'tareas_diarias_push' => {
        'cron'  => '0 8 * * *',
        'class' => 'TareasDiariasPushJob',
        'description' => 'Envía push notification con resumen de tareas del día a cada cultivador'
      }
    )
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end
