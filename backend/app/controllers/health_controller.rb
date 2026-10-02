class HealthController < ApplicationController

  # GET /up — el health check de RENDER. Tiene que seguir siendo trivial: si falla, Render
  # reinicia el servicio web, y reiniciarlo porque Redis o el worker andan mal no arregla nada.
  def show
    render json: { ok: true, time: Time.current }
  end

  # GET /salud — para el monitor EXTERNO (UptimeRobot / Better Stack): ¿anda todo lo que la app
  # necesita? 200 si sí, 503 si algo no. Es público a propósito (el monitor no se loguea), por eso
  # dice sólo «ok»/«caído» por pieza: ni versiones, ni hosts, ni datos de nadie.
  #
  # Qué es «anda» lo decide `Infra::Chequeos`, lo mismo que mira el panel de plataforma.
  def salud
    piezas   = Infra::Chequeos.call
    chequeos = piezas.transform_values { |p| p[:estado] == 'mal' ? 'caído' : 'ok' }
    todo_ok  = chequeos.values.all?('ok')
    render json: { ok: todo_ok, chequeos: chequeos, time: Time.current },
           status: todo_ok ? :ok : :service_unavailable
  end

  # GET /salud/backup — para un SEGUNDO monitor externo: ¿hubo backup en las últimas 26 horas?
  # Un cron que se rompe no avisa (pasó: semanas sin backup). Con esto el monitor manda el mail.
  # Mismo criterio que el panel (`Backups::Ultimo`). Sin bucket configurado no hay qué vigilar.
  def backup
    b  = Backups::Ultimo.call
    ok = b[:estado] == 'ok'
    render json: { ok: ok, estado: b[:estado], horas_desde: b[:horas_desde], time: Time.current },
           status: ok ? :ok : :service_unavailable
  end
end
