# Categorías de producto del salón (Bebidas, Cocina, Merch…), editables por el club. Lectura:
# admin/supervisor/dispensador. Gestión (crear/renombrar/eliminar): admin/supervisor.
class CategoriasProductoController < ApplicationController
  before_action :authenticate_user!
  before_action :asegurar_categorias, only: [:index]
  before_action :require_lectura,     only: [:index]
  before_action :require_gestion,     only: [:create, :update, :destroy]
  before_action :set_categoria,       only: [:update, :destroy]

  # GET /categorias_producto
  def index
    render json: current_user.club.categorias_producto.ordenadas.map { |c| serialize(c) }
  end

  # POST /categorias_producto
  def create
    c = current_user.club.categorias_producto.build(categoria_params)
    c.es_sistema = false
    if c.save
      render json: serialize(c), status: :created
    else
      render json: { errors: c.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /categorias_producto/:id
  def update
    if @categoria.update(categoria_params)
      render json: serialize(@categoria)
    else
      render json: { errors: @categoria.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /categorias_producto/:id
  def destroy
    if @categoria.es_sistema
      return render json: { error: 'Es una categoría del sistema; no se borra. Podés desactivarla.' }, status: :unprocessable_entity
    end
    if @categoria.bar_productos.exists?
      return render json: { error: 'La categoría tiene productos asignados. Reasignalos o desactivala en vez de borrarla.' }, status: :unprocessable_entity
    end
    @categoria.destroy
    head :no_content
  end

  private

  def set_categoria
    @categoria = current_user.club.categorias_producto.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Categoría no encontrada' }, status: :not_found
  end

  def asegurar_categorias
    Bar::SembrarCategoriasProducto.new(current_user.club).call if current_user.club.categorias_producto.none?
  end

  ROLES_LECTURA = %w[admin supervisor dispensador].freeze
  ROLES_GESTION = %w[admin supervisor].freeze

  def require_lectura
    render json: { error: 'No autorizado' }, status: :forbidden unless ROLES_LECTURA.include?(current_user&.role)
  end

  def require_gestion
    render json: { error: 'No autorizado' }, status: :forbidden unless ROLES_GESTION.include?(current_user&.role)
  end

  def categoria_params
    params.require(:categoria_producto).permit(:nombre, :orden, :activo)
  end

  def serialize(c)
    {
      id:              c.id,
      nombre:          c.nombre,
      orden:           c.orden,
      activo:          c.activo,
      es_sistema:      c.es_sistema,
      clave_sistema:   c.clave_sistema,
      productos_count: c.bar_productos.count,
    }
  end
end
