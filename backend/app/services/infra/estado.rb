# EL PANEL DE ESTADO DE LA PLATAFORMA: ¿anda todo? Y si no, qué y qué hacer.
#
# Junta lo de adentro (`Infra::Chequeos`, `Infra::Cola`, `Backups::Ultimo`), lo de Render
# (`Infra::Servidores`) y el tamaño de cada organización (`Infra::Organizaciones`), y lo resume en
# UNA frase y un semáforo. Está pensado para que lo entienda cualquiera que lo abra: cada aviso dice
# qué pasa en castellano y qué hacer, sin jerga.
#
# Si la app se cae, este panel se cae con ella: para eso está el monitor externo (`/salud`), que
# avisa por mail. Esto es para mirar, aquello para enterarse.
module Infra
  class Estado
    ORDEN = { 'mal' => 0, 'atencion' => 1, 'info' => 2 }.freeze
    # La verificación corre todos los días después del backup: si la última tiene más de esto,
    # el cron de verificación dejó de correr.
    DIAS_VERIFICACION_VIEJA = 3

    def self.call = new.call

    def call
      @chequeos   = Chequeos.call
      @cola       = Cola.call
      @backup     = Backups::Ultimo.call
      @servidores = Servidores.call
      avisos = (avisos_internos + avisos_backup + avisos_cola + avisos_servidores + avisos_monitoreo)
               .sort_by { |a| ORDEN[a[:nivel]] }
      general = avisos.any? { |a| a[:nivel] == 'mal' } ? 'mal' : avisos.any? { |a| a[:nivel] == 'atencion' } ? 'atencion' : 'ok'

      {
        generado_at:    Time.current,
        estado:         general,
        frase:          frase(general, avisos),
        avisos:         avisos,
        chequeos:       @chequeos,
        cola:           @cola,
        backup:         @backup,
        servidores:     @servidores,
        organizaciones: Organizaciones.call,
        monitoreo:      monitoreo,
      }
    end

    private

    def frase(general, avisos)
      case general
      when 'ok'       then 'Todo funciona.'
      when 'atencion' then "Funciona, pero hay #{n(avisos, 'atencion')} para mirar."
      else "Hay #{n(avisos, 'mal')} que no funciona#{avisos.count { |a| a[:nivel] == 'mal' } == 1 ? '' : 'n'}."
      end
    end

    def n(avisos, nivel)
      c = avisos.count { |a| a[:nivel] == nivel }
      "#{c} #{c == 1 ? 'cosa' : 'cosas'}"
    end

    def aviso(nivel, que, hacer) = { nivel: nivel, que: que, hacer: hacer }

    def avisos_internos
      a = []
      if @chequeos[:base][:estado] == 'mal'
        a << aviso('mal', 'La base de datos no responde: la app no puede trabajar.', 'Render → la base de datos → ver si está «Available». Seguir docs/INFRA.md, «Se cayó la app».')
      elsif @chequeos[:base][:estado] == 'atencion'
        a << aviso('atencion', "La base de datos contesta lento (#{@chequeos[:base][:ms]} ms).", 'Mirar el uso de CPU y memoria de la base más abajo; si está al tope, hay que subirla de plan.')
      end
      r = @chequeos[:redis]
      if r[:estado] == 'mal'
        a << aviso('mal', 'Redis no responde: los trabajos en segundo plano y la actualización en vivo no andan.', 'Render → Redis → ver su estado.')
      elsif r[:politica].present? && r[:politica] != 'noeviction'
        a << aviso('atencion', "Redis está configurado para borrar datos cuando se llena («#{r[:politica]}»): se pueden perder trabajos.", 'Render → Redis → Maxmemory Policy → «noeviction».')
      elsif r[:memoria_pct].to_i >= 90
        a << aviso('atencion', "Redis está casi lleno (#{r[:memoria_pct]} %).", 'Subir Redis de plan en Render.')
      end
      if @chequeos[:worker][:estado] == 'mal'
        a << aviso('mal', 'Los trabajos en segundo plano no están corriendo: no salen avisos de REPROCANN, push ni correos.', 'Render → club-cultivo-worker → Logs. Si está caído, «Manual Deploy». Ver docs/INFRA.md.')
      end
      a
    end

    def avisos_backup
      b = @backup
      return [aviso('atencion', "No se pudo mirar los backups: #{b[:motivo]}", 'Revisar las variables del bucket en el servidor (docs/INFRA.md, Backups).')] unless b[:disponible]

      a = []
      case b[:estado]
      when 'mal'      then a << aviso('mal', b[:ultimo] ? "Hace #{b[:horas_desde].round} horas que no hay backup." : 'No hay ningún backup.', 'Render → db-backup-diario → Logs, y «Trigger Run» para correrlo ya.')
      when 'atencion' then a << aviso('atencion', "El backup de hoy no corrió (el último es de hace #{b[:horas_desde].round} horas).", 'Render → db-backup-diario → Logs.')
      end
      v = b[:verificacion]
      if v.nil?
        a << aviso('atencion', 'Ningún backup fue verificado todavía.', 'Crear el cron de verificación en Render (docs/INFRA.md, paso 4).')
      elsif !v['ok']
        a << aviso('mal', 'El último backup verificado NO se puede usar.', 'Render → backup-verificacion → Logs. Avisar enseguida.')
      elsif Time.zone.parse(v['verificado_at'].to_s) < DIAS_VERIFICACION_VIEJA.days.ago
        a << aviso('atencion', 'La verificación de los backups dejó de correr.', 'Render → backup-verificacion → Logs.')
      end
      a << aviso('info', 'Los backups están en el mismo bucket que las fotos y documentos de los pacientes.', 'Crear un bucket aparte para los backups (docs/INFRA.md, paso 5).') if b[:bucket_compartido]
      a
    end

    def avisos_cola
      a = []
      t = @cola[:trabajos]
      if t[:disponible]
        a << aviso('atencion', "Hay trabajos esperando hace #{(t[:espera_seg] / 60.0).round} minutos.", 'El worker no da abasto o está trabado: Render → club-cultivo-worker → Logs.') if t[:espera_seg].to_i > Cola::ESPERA_ATENCION_SEG
        a << aviso('atencion', "#{t[:muertos]} trabajo#{t[:muertos] == 1 ? '' : 's'} fallaron del todo y no se van a reintentar.", 'Abrir /sidekiq → «Dead» y ver el error.') if t[:muertos].to_i.positive?
      end
      atrasados = Array(@cola[:cron]).select { |c| c[:atrasado] }
      if atrasados.any?
        uno    = atrasados.size == 1
        nombres = atrasados.first(4).map { |c| c[:nombre] }.join(', ')
        nombres += " y #{atrasados.size - 4} más" if atrasados.size > 4
        a << aviso('atencion', "#{atrasados.size} tarea#{uno ? '' : 's'} programada#{uno ? '' : 's'} no #{uno ? 'corrió' : 'corrieron'} cuando debía#{uno ? '' : 'n'}: #{nombres}.",
                   'Si el worker está andando, reiniciarlo registra las tareas de nuevo.')
      end
      a
    end

    def avisos_servidores
      s = @servidores
      return [aviso('info', 'El panel todavía no lee Render (falta la llave).', 'Cargar RENDER_API_KEY (docs/INFRA.md, paso 2).')] unless s[:configurado]
      return [aviso('atencion', "No se pudo leer Render: #{s[:error]}", 'Volver a cargar la página en un rato; si sigue, revisar RENDER_API_KEY.')] if s[:error]

      a = s[:servidores].select { |x| x[:en_produccion] && %w[mal atencion].include?(x[:estado]) }
                        .map { |x| aviso(x[:estado], "#{x[:titulo]}: #{x[:estado_texto]}.", "Render → #{x[:nombre]}.") }
      prendidos_de_mas = s[:servidores].reject { |x| x[:en_produccion] || x[:estado] == 'apagado' }
      if prendidos_de_mas.any?
        a << aviso('info', "Hay #{prendidos_de_mas.size} servicio#{prendidos_de_mas.size == 1 ? '' : 's'} en Render que no son de producción: #{prendidos_de_mas.map { |x| x[:nombre] }.join(', ')}.",
                   'Si no se usan, borrarlos (docs/INFRA.md, paso 6).')
      end
      a
    end

    def avisos_monitoreo
      a = []
      a << aviso('info', 'Sentry no está prendido: no se miden los tiempos ni los errores de producción.', 'Cargar SENTRY_DSN (docs/INFRA.md, paso 1).') unless monitoreo[:sentry]
      a
    end

    def monitoreo
      @monitoreo ||= { sentry: ENV['SENTRY_DSN'].present?, sentry_url: ENV['SENTRY_URL'].presence,
                       render: RenderApi.configurado? }
    end
  end
end
