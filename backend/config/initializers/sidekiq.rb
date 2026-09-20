redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }

  config.on(:startup) do
    Sidekiq::Cron::Job.load_from_hash(
      'jwt_denylist_cleanup' => {
        'cron'  => '0 * * * *',
        'class' => 'JwtDenylistCleanupJob'
      },
      'purgar_adjuntos_entrega' => {
        # De madrugada: toca adjuntos y no hay nadie mirando una entrega vieja a esa hora.
        'cron'  => '40 4 * * *',
        'class' => 'PurgarAdjuntosEntregaJob',
        'description' => 'Borra firma y foto de las entregas pasados 30 días (deja el rastro en la bitácora del envío)'
      },
      'aplicar_bajas_modulos' => {
        # Temprano, antes de que la organización arranque el día: el módulo se apaga sin que
        # nadie esté a mitad de una operación.
        'cron'  => '5 5 * * *',
        'class' => 'AplicarBajasModulosJob',
        'description' => 'Apaga los módulos cuya baja programada ya venció y ordena lo que dejan colgando'
      },
      'plan_vencimiento' => {
        'cron'  => '30 8 * * *',
        'class' => 'PlanVencimientoJob',
        'description' => 'Avisa al admin de la organización que su plan vence en 7 días o venció hoy'
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
        'description' => 'Genera alertas de stock bajo (umbral configurable por club) para todos los clubes'
      },
      'cierre_mostrador_pendiente' => {
        # BARRE CADA DIEZ MINUTOS, y no arranca "a la hora límite" porque no hay UNA hora: cada
        # organización elige la suya y cada sede puede tener otra, así que un cron —que es global—
        # no puede saberla. Lo que hace cada pasada es preguntar si esa hora ya pasó
        # (`Time.zone.now < limite` → sigue de largo): antes del límite no avisa nada, y después
        # avisa UNA vez por mostrador y por día. Lo único que fija el intervalo es cuánto tarde
        # llega el aviso.
        'cron'  => '*/10 * * * *',
        'class' => 'CierreMostradorPendienteJob',
        'description' => 'Avisa al admin si la caja del mostrador sigue abierta pasada la hora que configuró'
      },
      'merma_mostrador' => {
        'cron'  => '30 9 * * 1',
        'class' => 'MermaMostradorJob',
        'description' => 'Avisa si la merma del mostrador se sale del patrón de esa organización'
      },
      'stock_vencimiento' => {
        'cron'  => '0 9 * * *',
        'class' => 'StockVencimientoJob',
        'description' => 'Genera alertas de stock vencido o próximo a vencer para todos los clubes'
      },
      'detectar_alertas_cultivo' => {
        'cron'  => '0 7 * * *',
        'class' => 'DetectarAlertasJob',
        'description' => 'Detecta anomalías de cultivo: registros vencidos, pH/EC fuera de rango, cosecha pendiente, tareas vencidas'
      },
      'asignacion_postcosecha' => {
        'cron'  => '10 8 * * *',
        'class' => 'AsignacionPostcosechaJob',
        'description' => 'Avisa o asigna a manicura los lotes cosechados que superan los días de gracia post-cosecha (config por club)'
      },
      'vencimiento_reservas' => {
        'cron'  => '15 8 * * *',
        'class' => 'VencimientoReservasJob',
        'description' => 'Vence reservas de dispensa pasadas de fecha (libera stock) y avisa las que se entregan hoy'
      },
      # Reemplaza al «resumen de tareas del día» de las 8:00: ahora cada tarea lleva su propio
      # «Recordarme» (Germán, 20-sep-2026). Cada 15 minutos se mandan los que tocan.
      'recordatorios_tareas' => {
        'cron'  => '*/15 * * * *',
        'class' => 'RecordatoriosTareasJob',
        'description' => 'Manda el push «Recordarme» de las tareas cuyo momento llegó (ese día o el día antes, a las 8)'
      },
      'informe_semestral_recordatorio_1' => {
        'cron'  => '0 8 1 6 *',
        'class' => 'InformeSemestralJob',
        'args'  => ['recordatorio'],
        'description' => 'Recordatorio: informe 1° semestre vence en 30 días (envía 1 de junio)'
      },
      'informe_semestral_recordatorio_2' => {
        'cron'  => '0 8 1 12 *',
        'class' => 'InformeSemestralJob',
        'args'  => ['recordatorio'],
        'description' => 'Recordatorio: informe 2° semestre vence en 30 días (envía 1 de diciembre)'
      },
      'informe_semestral_envio_1' => {
        'cron'  => '0 8 1 7 *',
        'class' => 'InformeSemestralJob',
        'args'  => ['envio'],
        'description' => 'Genera y envía informe 1° semestre al equipo admin (1 de julio)'
      },
      'informe_semestral_envio_2' => {
        'cron'  => '0 8 1 1 *',
        'class' => 'InformeSemestralJob',
        'args'  => ['envio'],
        'description' => 'Genera y envía informe 2° semestre al equipo admin (1 de enero)'
      }
    )
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end
