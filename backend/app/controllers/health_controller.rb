class HealthController < ApplicationController

  # GET /up — el health check de RENDER. Tiene que seguir siendo trivial: si falla, Render
  # reinicia el servicio web, y reiniciarlo porque Redis o el worker andan mal no arregla nada.
  def show
    render json: { ok: true, time: Time.current }
  end

  # GET /salud — para el monitor EXTERNO (UptimeRobot / Better Stack): ¿anda todo lo que la app
  # necesita? 200 si sí, 503 si algo no. Es público a propósito (el monitor no se loguea), por eso
  # dice sólo «ok»/«caído» por pieza: ni versiones, ni hosts, ni datos de nadie.
  def salud
    chequeos = {
      base:   chequear { ActiveRecord::Base.connection.select_value('SELECT 1') == 1 },
      redis:  chequear { Sidekiq.redis { |r| r.call('PING') } == 'PONG' },
      worker: chequear { worker_vivo? },
    }
    todo_ok = chequeos.values.all?('ok')
    render json: { ok: todo_ok, chequeos: chequeos, time: Time.current },
           status: todo_ok ? :ok : :service_unavailable
  end

  private

  def chequear
    yield ? 'ok' : 'caído'
  rescue StandardError
    'caído'
  end

  # Sin un proceso de Sidekiq vivo los jobs se encolan y nadie los corre, sin ningún error visible
  # (pasó 79 días en producción). El latido de Sidekiq es cada ~10 s: un minuto sin latir es caído.
  def worker_vivo?
    require 'sidekiq/api'
    Sidekiq::ProcessSet.new.any? { |p| Time.now.to_i - p['beat'].to_i < 60 }
  end
end
