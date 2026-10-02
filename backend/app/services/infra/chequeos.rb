# LAS TRES PIEZAS SIN LAS QUE LA APP NO ATIENDE, vistas desde adentro: la base, Redis y el worker.
#
# Una sola definición de «anda» para los dos que preguntan: el monitor externo (`GET /salud`, cada
# minuto) y el panel de plataforma (Estado). Si cada uno lo midiera a su manera, algún día uno diría
# verde y el otro rojo sobre lo mismo.
#
# Cada pieza devuelve `estado` (ok / atencion / mal) y los números que lo explican. Nunca levanta:
# que una pieza no conteste ES el dato.
module Infra
  class Chequeos
    # El latido de Sidekiq es cada ~10 s: un minuto sin latir es un worker caído.
    LATIDO_MAXIMO_SEG = 60
    # Una consulta trivial a la base que tarda más que esto es una base en problemas.
    BASE_LENTA_MS = 300

    def self.call = new.call

    def call
      { base: base, redis: redis, worker: worker }
    end

    def base
      ms = medir { ActiveRecord::Base.connection.select_value('SELECT 1') }
      { estado: ms > BASE_LENTA_MS ? 'atencion' : 'ok', ms: ms }
    rescue StandardError => e
      caido(e)
    end

    # Además de que conteste: cuánta memoria usa y con qué política. Con una política distinta de
    # `noeviction`, Redis borra claves cuando se llena y Sidekiq pierde trabajos sin avisar.
    def redis
      ms   = medir { Sidekiq.redis { |r| r.call('PING') } }
      info = Sidekiq.redis { |r| r.call('INFO', 'memory') }.to_s
      dato = ->(k) { info[/^#{k}:(\S+)/, 1] }
      usada  = dato.call('used_memory').to_i
      maxima = dato.call('maxmemory').to_i
      politica = dato.call('maxmemory_policy')
      pct = maxima.positive? ? (usada * 100.0 / maxima).round : nil
      estado = if politica.present? && politica != 'noeviction' then 'atencion'
               elsif pct && pct >= 90 then 'atencion'
               else 'ok'
               end
      { estado: estado, ms: ms, memoria_mb: (usada / 1024.0 / 1024).round(1),
        memoria_max_mb: maxima.positive? ? (maxima / 1024.0 / 1024).round : nil, memoria_pct: pct,
        politica: politica }
    rescue StandardError => e
      caido(e)
    end

    # Sin un proceso de Sidekiq vivo los trabajos se encolan y nadie los corre, sin ningún error
    # visible (pasó 79 días en producción).
    def worker
      require 'sidekiq/api'
      procesos = Sidekiq::ProcessSet.new.to_a
      latidos  = procesos.map { |p| Time.now.to_i - p['beat'].to_i }
      vivos    = latidos.count { |s| s < LATIDO_MAXIMO_SEG }
      { estado: vivos.positive? ? 'ok' : 'mal', procesos: vivos,
        ultimo_latido_seg: latidos.min,
        hilos: procesos.sum { |p| p['concurrency'].to_i } }
    rescue StandardError => e
      caido(e)
    end

    private

    def medir
      t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      yield
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) * 1000).round(1)
    end

    def caido(e)
      Rails.logger.warn("[infra] #{e.class} #{e.message}")
      { estado: 'mal', error: 'No responde.' }
    end
  end
end
