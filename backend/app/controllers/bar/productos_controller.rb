module Bar
  # Productos de un bar concreto (anidado bajo /bares/:bar_id). Lectura y reposición:
  # admin/supervisor/dispensador. Alta/edición/borrado de catálogo: admin. Feature flag :bar.
  # Borrado = soft (recuperable desde la papelera).
  class ProductosController < ApplicationController
    before_action :authenticate_user!
    before_action :require_feature_bar!
    before_action :set_bar
    before_action :require_operador, only: [:index, :reponer]
    before_action :require_admin_bar, only: [:create, :update, :destroy]
    before_action :set_producto, only: [:update, :destroy, :reponer]

    # GET /bares/:bar_id/productos
    def index
      scope = @bar.bar_productos
      scope = scope.activos if params[:activos] == 'true'
      render json: scope.order(:categoria, :nombre).map { |p| serialize(p) }
    end

    # POST /bares/:bar_id/productos
    def create
      prod = @bar.bar_productos.build(producto_params.merge(club: current_user.club, unidad_negocio: @bar.unidad_negocio_bar))
      if prod.save
        render json: serialize(prod), status: :created
      else
        render json: { errors: prod.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PATCH /bares/:bar_id/productos/:id
    def update
      if @producto.update(producto_params)
        render json: serialize(@producto)
      else
        render json: { errors: @producto.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /bares/:bar_id/productos/:id — soft-delete
    def destroy
      @producto.update!(deleted_by_id: current_user.id)
      @producto.destroy
      head :no_content
    end

    # POST /bares/:bar_id/productos/:id/reponer  { cantidad }
    def reponer
      cant = params.require(:cantidad).to_d
      return render json: { error: 'Cantidad inválida' }, status: :unprocessable_entity if cant <= 0

      @producto.update!(stock: @producto.stock.to_d + cant)
      render json: serialize(@producto)
    rescue ActionController::ParameterMissing
      render json: { error: 'Falta la cantidad' }, status: :unprocessable_entity
    end

    private

    def set_bar
      @bar = current_user.club.bares.find(params[:bar_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Bar no encontrado' }, status: :not_found
    end

    def set_producto
      @producto = @bar.bar_productos.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Producto no encontrado' }, status: :not_found
    end

    def require_feature_bar!
      return if current_user.club.feature?(:bar)

      render json: { error: 'El bar no está habilitado para este club.' }, status: :forbidden
    end

    ROLES_OPERADOR = %w[admin supervisor dispensador].freeze

    def require_operador
      render json: { error: 'No autorizado' }, status: :forbidden unless ROLES_OPERADOR.include?(current_user&.role)
    end

    def require_admin_bar
      render json: { error: 'Solo el admin configura los productos del bar' }, status: :forbidden unless current_user.admin?
    end

    def producto_params
      params.require(:bar_producto).permit(:nombre, :categoria, :precio_ars, :costo_ars, :stock, :stock_minimo, :activo)
    end

    def serialize(p)
      {
        id: p.id, nombre: p.nombre, categoria: p.categoria,
        precio_ars: p.precio_ars.to_f, costo_ars: p.costo_ars&.to_f,
        stock: p.stock.to_f, stock_minimo: p.stock_minimo.to_f, stock_bajo: p.stock_bajo?,
        margen_pct: p.margen_pct, activo: p.activo,
      }
    end
  end
end
