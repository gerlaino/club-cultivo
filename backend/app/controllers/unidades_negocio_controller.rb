# CRUD de unidades de negocio editables por club. Lectura: admin/auditor. Escritura: admin.
# Las unidades de sistema (es_sistema) no se pueden borrar; sí renombrar/desactivar.
class UnidadesNegocioController < ApplicationController
  before_action :authenticate_user!
  before_action :require_lectura,   only: [:index]
  before_action :require_escritura, only: [:create, :update, :destroy]
  before_action :asegurar_catalogo, only: [:index]
  before_action :set_unidad,        only: [:update, :destroy]

  # GET /unidades_negocio
  def index
    scope = current_user.club.unidades_negocio.ordenadas
    scope = scope.activas if params[:activas] == 'true'
    render json: scope.map { |u| serialize(u) }
  end

  # POST /unidades_negocio
  #
  # LOS SECTORES SON CINCO Y NO SE CREAN (ver UnidadNegocio::CANONICOS). Se sembraban tres y el
  # admin podía agregar los suyos, cada uno con su depósito: así aparecían varios depósitos para
  # el mismo sector y no había forma de saber cuál era el bueno. Los cinco los siembra
  # `Finanzas::SembrarCatalogo` y se pueden renombrar o desactivar, no crear.
  def create
    render json: {
      error: 'Los sectores son fijos: General, Cultivo, Dispensario, Buffet y Otro. ' \
             'Podés renombrarlos o desactivarlos, pero no crear otros.',
    }, status: :unprocessable_entity
  end

  # PATCH /unidades_negocio/:id
  def update
    if @unidad.update(unidad_params)
      render json: serialize(@unidad)
    else
      render json: { errors: @unidad.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /unidades_negocio/:id
  def destroy
    if @unidad.es_sistema?
      return render json: { error: 'Esta unidad es del sistema y no puede eliminarse. Podés desactivarla.' }, status: :unprocessable_entity
    end
    if @unidad.movimientos_contables.exists? || @unidad.categorias_contables.exists?
      return render json: { error: 'La unidad tiene categorías o movimientos asociados. Desactivala en vez de borrarla.' }, status: :unprocessable_entity
    end

    @unidad.destroy
    head :no_content
  end

  private

  def set_unidad
    @unidad = current_user.club.unidades_negocio.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Unidad no encontrada' }, status: :not_found
  end

  def asegurar_catalogo
    return if current_user.club.unidades_negocio.exists?

    Finanzas::SembrarCatalogo.new(current_user.club).call
  end

  def unidad_params
    params.require(:unidad_negocio).permit(:nombre, :tipo, :color, :orden, :activa)
  end

  def require_lectura
    unless current_user.admin? || current_user.auditor?
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end

  def require_escritura
    unless current_user.admin?
      render json: { error: 'Solo administradores pueden gestionar unidades de negocio' }, status: :forbidden
    end
  end

  def serialize(u)
    {
      id:         u.id,
      nombre:     u.nombre,
      tipo:       u.tipo,
      color:      u.color,
      activa:     u.activa,
      orden:      u.orden,
      es_sistema: u.es_sistema,
      # ¿La organización contrató el pack que le da sentido a este sector? Se informa, NO se
      # filtra: un sector que quedó sin pack sigue teniendo movimientos históricos y su columna
      # en el P&L tiene que seguir cuadrando. Lo que cambia es que no se ofrece para clasificar
      # nada nuevo.
      disponible: u.disponible_para?(current_user.club),
    }
  end
end
