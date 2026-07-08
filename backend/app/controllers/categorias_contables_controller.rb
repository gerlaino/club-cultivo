# CRUD de categorías contables editables por club. Lectura: admin/auditor. Escritura: admin.
# Las categorías de sistema (es_sistema) no se pueden borrar; sí renombrar/recolorear/reasignar.
class CategoriasContablesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_lectura,   only: [:index]
  before_action :require_escritura, only: [:create, :update, :destroy]
  before_action :asegurar_catalogo, only: [:index]
  before_action :set_categoria,     only: [:update, :destroy]

  # GET /categorias_contables
  def index
    scope = current_user.club.categorias_contables.includes(:unidad_negocio).ordenadas
    scope = scope.where(tipo: params[:tipo]) if params[:tipo].present?
    scope = scope.activas                    if params[:activas] == 'true'
    render json: scope.map { |c| serialize(c) }
  end

  # POST /categorias_contables
  def create
    categoria = current_user.club.categorias_contables.build(categoria_params)
    if categoria.save
      render json: serialize(categoria), status: :created
    else
      render json: { errors: categoria.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /categorias_contables/:id
  def update
    if @categoria.update(categoria_params)
      render json: serialize(@categoria)
    else
      render json: { errors: @categoria.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /categorias_contables/:id
  def destroy
    if @categoria.es_sistema?
      return render json: { error: 'Esta categoría es del sistema y no puede eliminarse. Podés desactivarla.' }, status: :unprocessable_entity
    end
    if @categoria.movimientos_contables.exists?
      return render json: { error: 'La categoría tiene movimientos. Desactivala en vez de borrarla para conservar el histórico.' }, status: :unprocessable_entity
    end

    @categoria.destroy
    head :no_content
  end

  private

  def set_categoria
    @categoria = current_user.club.categorias_contables.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Categoría no encontrada' }, status: :not_found
  end

  # Sistema: si el club nunca entró a Finanzas, siembra el catálogo desde los enums legacy.
  def asegurar_catalogo
    return if current_user.club.categorias_contables.exists?

    Finanzas::SembrarCatalogo.new(current_user.club).call
  end

  def categoria_params
    params.require(:categoria_contable).permit(
      :nombre, :tipo, :color, :unidad_negocio_id, :orden, :activa
    )
  end

  def require_lectura
    unless current_user.admin? || current_user.auditor?
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end

  def require_escritura
    unless current_user.admin?
      render json: { error: 'Solo administradores pueden gestionar categorías' }, status: :forbidden
    end
  end

  def serialize(c)
    {
      id:                c.id,
      nombre:            c.nombre,
      tipo:              c.tipo,
      color:             c.color,
      clave_sistema:     c.clave_sistema,
      es_sistema:        c.es_sistema,
      activa:            c.activa,
      orden:             c.orden,
      unidad_negocio_id: c.unidad_negocio_id,
      unidad_negocio:    c.unidad_negocio ? { id: c.unidad_negocio.id, nombre: c.unidad_negocio.nombre, tipo: c.unidad_negocio.tipo } : nil,
    }
  end
end
