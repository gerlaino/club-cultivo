# UNA TARJETA POR SERVIDOR, EN PALABRAS QUE ENTIENDE CUALQUIERA.
#
# Toma lo que dice Render (`Infra::RenderApi`) y lo traduce: qué es cada cosa («La app», «Trabajos en
# segundo plano», «Base de datos»), si anda, cuándo fue el último cambio, cuánto usa de lo que tiene
# y cuánto cuesta por mes.
#
# CUÁLES SON LOS DE PRODUCCIÓN no se adivina por el nombre —el de producción se llama
# `cultivo-staging-api`, que es exactamente al revés—: el servidor web se reconoce porque Render le
# pasa su propio id (`RENDER_SERVICE_ID`), y la base y el Redis porque su id está en `DATABASE_URL` /
# `REDIS_URL`. El worker y el cron, por nombre (`NOMBRES`), que es lo único que hay.
#
# Los precios son DE LISTA y estimados (`PLANES`): Render no expone la factura por API. El número
# exacto está en Render → Billing. Si cambian los precios, se cambian acá.
module Infra
  class Servidores
    CACHE = 'plataforma/servidores'.freeze
    TTL   = 2.minutes

    # Lo que se sabe de cada servicio por nombre. Lo que no está acá se muestra con su nombre de Render.
    NOMBRES = {
      'cultivo-staging-api' => { titulo: 'La app',                      que_hace: 'Atiende a todos los usuarios: pantallas y datos.' },
      'club-cultivo-worker' => { titulo: 'Trabajos en segundo plano',   que_hace: 'Avisos de REPROCANN, push, correos, alertas e informes.' },
      'db-backup-diario'    => { titulo: 'Backup diario',               que_hace: 'Copia la base al bucket todos los días a las 4 AM.' },
      'backup-verificacion' => { titulo: 'Verificación del backup',     que_hace: 'Revisa que el backup del día se pueda leer.' },
      'club-cultivo-1'      => { titulo: 'Sitio viejo (sin uso)',       que_hace: 'Versión anterior del frontend. Se puede borrar.' },
    }.freeze
    PRODUCCION_POR_NOMBRE = %w[club-cultivo-worker db-backup-diario backup-verificacion].freeze

    # Memoria (MB), CPU y precio en USD por mes, de lista. Estimado: la factura manda.
    PLANES = {
      'servicio' => {
        'free' => { ram: 512, cpu: 0.1, usd: 0 },  'starter' => { ram: 512, cpu: 0.5, usd: 7 },
        'standard' => { ram: 2048, cpu: 1, usd: 25 }, 'pro' => { ram: 4096, cpu: 2, usd: 85 },
        'pro_plus' => { ram: 8192, cpu: 4, usd: 175 },
      },
      'cron' => { 'starter' => { usd: 1 }, 'standard' => { usd: 3 } },
      'base' => {
        'free' => { usd: 0 }, 'basic_256mb' => { ram: 256, usd: 6 }, 'basic_1gb' => { ram: 1024, usd: 19 },
        'basic_4gb' => { ram: 4096, usd: 75 }, 'starter' => { ram: 256, usd: 7 }, 'standard' => { ram: 1024, usd: 20 },
      },
      'redis' => { 'free' => { ram: 25, usd: 0 }, 'starter' => { ram: 256, usd: 10 }, 'standard' => { ram: 1024, usd: 32 } },
    }.freeze

    TIPOS = { 'web_service' => 'web', 'background_worker' => 'worker', 'cron_job' => 'cron',
              'static_site' => 'estatico', 'private_service' => 'web' }.freeze

    DEPLOY_FALLIDO = %w[build_failed update_failed pre_deploy_failed].freeze
    DEPLOY_EN_CURSO = %w[created queued build_in_progress update_in_progress pre_deploy_in_progress].freeze

    def self.call(api: nil)
      return { configurado: false, motivo: 'Falta RENDER_API_KEY en el servidor (ver docs/INFRA.md).' } unless api || RenderApi.configurado?

      Rails.cache.fetch(CACHE, expires_in: TTL) { new(api || RenderApi.new).call }
    rescue RenderApi::Error => e
      { configurado: true, error: e.message, servidores: [] }
    end

    def initialize(api)
      @api = api
    end

    def call
      servidores = servicios + bases + redis
      activos = servidores.reject { |s| s[:estado] == 'apagado' }
      {
        configurado: true,
        servidores:  servidores.sort_by { |s| [s[:en_produccion] ? 0 : 1, s[:estado] == 'apagado' ? 1 : 0, s[:titulo]] },
        costo_usd_mes: activos.sum { |s| s[:precio_usd].to_f }.round,
        sin_precio:  activos.count { |s| s[:precio_usd].nil? },
        sobran:      servidores.reject { |s| s[:en_produccion] }.map { |s| s[:nombre] },
      }
    end

    private

    def servicios
      @api.servicios.map do |s|
        tipo  = TIPOS[s['type']] || s['type']
        plan  = norm(s.dig('serviceDetails', 'plan'))
        prod  = s['id'] == ENV['RENDER_SERVICE_ID'] || PRODUCCION_POR_NOMBRE.include?(s['name'])
        info  = NOMBRES[s['name']] || {}
        datos = PLANES.dig(tipo == 'cron' ? 'cron' : 'servicio', plan) || {}
        deploy = s['suspended'] == 'suspended' ? nil : @api.ultimo_deploy(s['id'])
        recursos = prod && %w[web worker].include?(tipo) ? recursos(s['id'], datos) : nil
        estado, texto = estado_servicio(s, deploy, recursos)
        {
          id: s['id'], nombre: s['name'], tipo: tipo, en_produccion: prod,
          titulo: info[:titulo] || s['name'], que_hace: info[:que_hace],
          plan: plan, precio_usd: s['suspended'] == 'suspended' ? 0 : datos[:usd],
          estado: estado, estado_texto: texto, deploy: resumen_deploy(deploy),
          recursos: recursos, panel_url: s['dashboardUrl'],
        }
      end
    end

    def bases
      url = parse(ENV['DATABASE_URL'])
      @api.postgres.map do |p|
        prod  = de_produccion?(p, url)
        plan  = norm(p['plan'])
        datos = PLANES.dig('base', plan) || {}
        apagada = p['suspended'] == 'suspended'
        estado, texto =
          if apagada then %w[apagado Suspendida]
          elsif p['status'] != 'available' then ['mal', "Render dice: #{p['status']}"]
          elsif p['expiresAt'].present? then ['atencion', "Plan gratis: se borra el #{Date.parse(p['expiresAt']).strftime('%d/%m')}"]
          else %w[ok Funcionando]
          end
        {
          id: p['id'], nombre: p['name'], tipo: 'base', en_produccion: prod,
          titulo: prod ? 'Base de datos' : "Base #{p['name']}",
          que_hace: prod ? 'Donde vive todo: pacientes, stock, dispensas, plata.' : nil,
          plan: plan, precio_usd: apagada ? 0 : datos[:usd], disco_gb: p['diskSizeGB'],
          alta_disponibilidad: p['highAvailabilityEnabled'], version: p['version'],
          estado: estado, estado_texto: texto,
          recursos: prod ? recursos(p['id'], datos) : nil,
          panel_url: p['dashboardUrl'],
        }
      end
    end

    def redis
      host = host_de(ENV['REDIS_URL'])
      @api.key_value.map do |r|
        prod  = host.present? && host.include?(r['id'].to_s)
        plan  = norm(r['plan'])
        apagado = r['suspended'] == 'suspended'
        estado, texto = if apagado then %w[apagado Suspendido]
                        elsif r['status'].present? && r['status'] != 'available' then ['mal', "Render dice: #{r['status']}"]
                        else %w[ok Funcionando]
                        end
        {
          id: r['id'], nombre: r['name'], tipo: 'redis', en_produccion: prod,
          titulo: prod ? 'Redis (fila de trabajos)' : "Redis #{r['name']}",
          que_hace: prod ? 'La fila de espera de los trabajos y el «al día solo» de las pantallas.' : nil,
          plan: plan, precio_usd: apagado ? 0 : PLANES.dig('redis', plan, :usd),
          estado: estado, estado_texto: texto, panel_url: r['dashboardUrl'],
        }
      end
    rescue RenderApi::Error
      []
    end

    def estado_servicio(s, deploy, recursos)
      return %w[apagado Suspendido] if s['suspended'] == 'suspended'

      st = deploy&.dig('status')
      return %w[atencion Desplegando…] if DEPLOY_EN_CURSO.include?(st)
      return ['atencion', 'El último cambio no se pudo instalar (sigue la versión anterior)'] if DEPLOY_FALLIDO.include?(st)
      return ['atencion', 'Memoria casi llena'] if recursos && recursos.dig(:memoria, :pct).to_i >= 90

      %w[ok Funcionando]
    end

    def resumen_deploy(d)
      return nil unless d

      { estado: d['status'], fecha: d['finishedAt'] || d['createdAt'],
        mensaje: d.dig('commit', 'message').to_s.lines.first.to_s.strip.presence,
        commit: d.dig('commit', 'id').to_s[0, 7].presence }
    end

    # Memoria y CPU de las últimas 24 horas: lo de ahora, el pico y cuánto es del plan.
    def recursos(id, plan)
      mem = @api.metrica('memory', id).map { |p| p.merge(v: (p[:v] / 1024 / 1024).round) }
      cpu = @api.metrica('cpu', id)
      {
        memoria: medida(mem, plan[:ram], 'MB'),
        cpu:     medida(cpu.map { |p| p.merge(v: p[:v].round(3)) }, plan[:cpu], 'CPU'),
      }
    rescue RenderApi::Error
      nil
    end

    def medida(serie, limite, unidad)
      return nil if serie.empty?

      actual = serie.last[:v]
      pico   = serie.map { |p| p[:v] }.max
      { actual: actual, pico: pico, limite: limite, unidad: unidad,
        pct: limite.to_f.positive? ? (actual * 100.0 / limite).round : nil,
        serie: serie.map { |p| p[:v] } }
    end

    def norm(plan) = plan.to_s.downcase.tr('-', '_').presence

    def host_de(url)
      URI.parse(url.to_s).host.to_s
    rescue URI::InvalidURIError
      ''
    end

    def parse(url)
      URI.parse(url.to_s)
    rescue URI::InvalidURIError
      nil
    end

    # ¿Es la base a la que está conectada la app? Por el id en el host (`dpg-…-a`), y si eso no
    # alcanza, por el nombre de la base y el usuario de `DATABASE_URL`: el 2-oct-2026 el id solo
    # no la reconoció y el panel la ofreció entre las que «se pueden borrar».
    def de_produccion?(p, url)
      return false if url.nil? || url.host.blank?

      id = p['id'].to_s
      return true if id.present? && url.host.include?(id)

      nombre = url.path.to_s.delete_prefix('/')
      nombre.present? && nombre == p['databaseName'].to_s && url.user.to_s == p['databaseUser'].to_s
    end
  end
end
