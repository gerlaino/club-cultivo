module Bar
  # Productos del bar. Lectura y reposición de stock: admin/supervisor/dispensador (operan el POS).
  # Alta/edición de catálogo (nombre, precio): admin. Feature flag :bar.
  class ProductosController < ApplicationController
    before_action :authenticate_user!
    before_action :require_feature_bar!
    before_action :require_operador, only: [:index, :reponer]
    before_action :require_admin_bar, only: [:create, :update, :destroy]
    before_action :set_producto, only: [:update, :destroy, :reponer]

    # GET /bar/productos
    def index
      scope = current_user.club.bar_productos
      scope = scope.activos if params[:activos] == 'true'
      render json: scope.order(:categoria, :nombre).map { |p| serialize(p) }
    end

    # POST /bar/productos
    def create
      prod = current_user.club.bar_productos.build(producto_params)
      prod.unidad_negocio ||= unidad_bar
      if prod.save
        render json: serialize(prod), status: :created
      else
        render json: { errors: prod.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PATCH /bar/productos/:id
    def update
      if @producto.update(producto_params)
        render json: serialize(@producto)
      else
        render json: { errors: @producto.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /bar/productos/:id
    def destroy
      @producto.destroy
      head :no_content
    end

    # POST /bar/productos/:id/reponer  { cantidad }
    def reponer
      cant = params.require(:cantidad).to_d
      return render json: { error: 'Cantidad inválida' }, status: :unprocessable_entity if cant <= 0

      @producto.update!(stock: @producto.stock.to_d + cant)
      render json: serialize(@producto)
    rescue ActionController::ParameterMissing
      render json: { error: 'Falta la cantidad' }, status: :unprocessable_entity
    end

    private

    def set_producto
      @producto = current_user.club.bar_productos.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Producto no encontrado' }, status: :not_found
    end

    def unidad_bar
      current_user.club.unidades_negocio.create_with(nombre: 'Bar', es_sistema: true).find_or_create_by!(tipo: 'bar')
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
