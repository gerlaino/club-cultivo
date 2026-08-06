namespace :sidekiq do
  # ¿Hay alguien procesando los jobs? Los cron (vencimientos de REPROCANN, indicaciones, stock,
  # alertas de cultivo, push) se registran al ARRANCAR el proceso Sidekiq. Si no hay un worker
  # corriendo, no se registra nada, no falla nada visible y los avisos simplemente no llegan.
  #
  #   bundle exec rake sidekiq:health
  #
  # Se corre desde la consola del servicio en Render (o de cualquier servicio que comparta el
  # mismo REDIS_URL: lo que se consulta es Redis, no el proceso local).
  desc 'Diagnóstico: ¿está corriendo el worker de Sidekiq y sus cron?'
  task health: :environment do
    require 'sidekiq/api'

    puts "\n══ SIDEKIQ ══"
    puts "REDIS_URL: #{ENV['REDIS_URL'].to_s.sub(%r{://([^:@/]+):[^@/]+@}, '://\1:****@').presence || '(no seteada — usa localhost)'}"

    procesos = Sidekiq::ProcessSet.new
    puts "\n── Procesos vivos: #{procesos.size}"
    if procesos.size.zero?
      puts '   ⛔ NO HAY NINGÚN WORKER CORRIENDO.'
      puts '      Los jobs se encolan y nadie los ejecuta: los vencimientos de REPROCANN, las'
      puts '      alertas de stock y los push NO se están enviando, sin ningún error visible.'
      puts '      → En Render hace falta un Background Worker con:'
      puts '        Start Command: bundle exec sidekiq -C config/sidekiq.yml'
      puts '        (mismo repo, mismo Root Directory, y el MISMO REDIS_URL que el web service)'
    else
      procesos.each do |p|
        puts "   ✓ #{p['hostname']} · #{p['concurrency']} hilos · colas: #{Array(p['queues']).join(', ')}"
        puts "     arrancó: #{Time.at(p['started_at']).utc} · latiendo hace #{(Time.now.to_i - p['beat'].to_i)}s"
      end
    end

    stats = Sidekiq::Stats.new
    puts "\n── Trabajo"
    puts "   procesados: #{stats.processed}   fallidos: #{stats.failed}"
    puts "   encolados : #{stats.enqueued}    reintentos: #{stats.retry_size}   muertos: #{stats.dead_size}"
    if stats.processed.to_i.zero? && stats.enqueued.to_i.positive?
      puts '   ⚠️  Hay trabajo encolado y CERO procesado: nadie está consumiendo la cola.'
    end

    puts "\n── Cron registrados"
    begin
      jobs = Sidekiq::Cron::Job.all
      if jobs.empty?
        puts '   ⛔ Ninguno. Se registran al arrancar el worker: si está vacío, el worker nunca arrancó.'
      else
        jobs.sort_by(&:name).each do |j|
          ultima = j.last_enqueue_time ? j.last_enqueue_time.utc.to_s : 'nunca'
          puts "   #{j.status == 'enabled' ? '✓' : '✗'} #{j.name.ljust(28)} #{j.cron.ljust(12)} última: #{ultima}"
        end
      end
    rescue StandardError => e
      puts "   (no se pudo leer el cron: #{e.message})"
    end

    puts "\n── Colas"
    Sidekiq::Queue.all.each { |q| puts "   #{q.name.ljust(12)} #{q.size} pendientes · latencia #{q.latency.round(1)}s" }
    puts "   (sin colas)" if Sidekiq::Queue.all.empty?

    puts "\n══ VEREDICTO ══"
    if procesos.size.zero?
      puts '⛔ SIN WORKER. Los avisos automáticos no están funcionando.'
    elsif Sidekiq::Cron::Job.all.empty?
      puts '⚠️  Hay worker pero sin cron cargados: revisá config/initializers/sidekiq.rb.'
    else
      puts '✓ Worker corriendo y cron registrados.'
    end
    puts
  end
end

namespace :sidekiq do
  # Vaciar las colas ANTES de levantar un worker que estuvo caído mucho tiempo.
  #
  # Sin esto, al arrancar se ejecutan de una todos los jobs acumulados: mails a pacientes,
  # push, y alertas de vencimientos que ya pasaron hace meses. El daño no es técnico —es que
  # el club recibe una avalancha de avisos viejos y pierde la confianza en los que sí importan.
  #
  # Perder estos jobs no cuesta nada: los cron vuelven a generarlos en su próxima corrida
  # (los vencimientos se recalculan todos los días desde el estado actual, no desde la cola).
  #
  #   rake sidekiq:purge              # muestra qué hay, NO borra
  #   rake sidekiq:purge CONFIRMAR=1  # vacía
  desc 'Vacía las colas acumuladas (usar antes de revivir un worker caído)'
  task purge: :environment do
    require 'sidekiq/api'

    colas = Sidekiq::Queue.all
    total = colas.sum(&:size)

    if total.zero?
      puts 'Las colas están vacías: nada que hacer.'
      next
    end

    puts "\nHay #{total} jobs encolados:"
    colas.each { |q| puts format('  %-14s %5d  (el más viejo, hace %.1f días)', q.name, q.size, q.latency / 86_400.0) }

    if ENV['CONFIRMAR'].blank?
      puts "\nNo se borró nada. Para vaciarlas: rake sidekiq:purge CONFIRMAR=1"
      puts 'Los cron los vuelven a generar en su próxima corrida.'
      next
    end

    colas.each { |q| puts "  vaciando #{q.name} (#{q.size})…"; q.clear }
    Sidekiq::RetrySet.new.clear
    Sidekiq::ScheduledSet.new.clear
    puts "\n✓ Colas vaciadas. Ahora sí, levantá el worker."
  end
end
