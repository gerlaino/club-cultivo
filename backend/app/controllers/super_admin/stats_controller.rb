# El panel del dueño de la plataforma. `show` y `metricas` —los recuentos de plantas y lotes,
# con `mrr: 0` escrito a mano— se retiraron en sep-2026: ninguna pantalla los llamaba, y lo que
# contestaban vive en `Pulso` (lo accionable y la plata) y en `InformesController#plataforma`
# (el tamaño de la plataforma).
class SuperAdmin::StatsController < SuperAdmin::BaseController
  # GET /super_admin/pulso — lo que el dueño de la plataforma necesita ver al abrir.
  def pulso
    render json: SuperAdmin::Pulso.new.call
  end
end
