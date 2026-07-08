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
  def create
    unidad = current_user.club.unidades_negocio.build(unidad_params)
    if unidad.save
      render json: serialize(unidad), status: :created
    else
      render json: { errors: unidad.errors.full_messages }, status: :unprocessable_entity
    end
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
    }
  end
end
