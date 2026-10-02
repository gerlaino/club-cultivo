# GET /super_admin/estado — el panel de Estado de la plataforma (servidores, backups, cola,
# tamaño de cada organización). El cálculo vive en `Infra::Estado`; acá sólo se entrega.
class SuperAdmin::EstadoController < SuperAdmin::BaseController
  def show
    render json: Infra::Estado.call
  end
end
