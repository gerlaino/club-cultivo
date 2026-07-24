module Bar
  # Productos de un bar concreto (anidado bajo /bares/:bar_id). Lectura y reposición:
  # admin/supervisor/dispensador. Alta/edición/borrado de catálogo: admin. Feature flag :bar.
  # Borrado = soft (recuperable desde la papelera).
  class ProductosController < ApplicationController
    before_action :authenticate_user!
    before_action :require_feature_bar!
    before_action :set_bar
    before_action :require_operador, only: [:index, :reponer, :movimientos]
    before_action :require_admin_bar, only: [:create, :update, :destroy, :comprar, :ajustar]
    before_action :set_producto, only: [:update, :destroy, :reponer, :comprar, :ajustar, :movimientos]

    # GET /bares/:bar_id/productos
    def index
      scope = @bar.bar_productos.includes(:categoria_producto)
      scope = scope.activos if params[:activos] == 'true'
      vendidos = vendidos_mes_map
      render json: scope.order(:categoria, :nombre).map { |p| serialize(p).merge(vendidos_mes: vendidos[p.id].to_f) }
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

      @producto.registrar_ingreso!(cantidad: cant, tipo: 'ajuste', created_by: current_user, motivo: 'Reposición manual')
      render json: serialize(@producto)
    rescue ActionController::ParameterMissing
      render json: { error: 'Falta la cantidad' }, status: :unprocessable_entity
    end

    # POST /bares/:bar_id/productos/:id/comprar  { cantidad, costo_total_ars, proveedor? }
    # Compra de mercadería: sube stock + costo promedio ponderado + egreso en el libro.
    def comprar
      compra = @producto.registrar_compra!(
        cantidad:        params.require(:cantidad),
        costo_total_ars: params.require(:costo_total_ars),
        proveedor:       params[:proveedor],
        created_by:      current_user
      )
      render json: serialize(@producto).merge(movimiento_id: compra.id), status: :created
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue ActionController::ParameterMissing => e
      render json: { error: "Falta el parámetro #{e.param}" }, status: :unprocessable_entity
    end

    # POST /bares/:bar_id/productos/:id/ajustar  { cantidad_nueva, motivo? }
    # Ajuste/merma: fija el stock al valor contado y registra la diferencia.
    def ajustar
      @producto.ajustar_stock!(
        cantidad_nueva: params.require(:cantidad_nueva),
        motivo:         params[:motivo],
        created_by:     current_user
      )
      render json: serialize(@producto)
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue ActionController::ParameterMissing => e
      render json: { error: "Falta el parámetro #{e.param}" }, status: :unprocessable_entity
    end

    # GET /bares/:bar_id/productos/:id/movimientos — historial de stock del producto
    def movimientos
      movs = @producto.bar_stock_movimientos.includes(:created_by).recientes.limit(80)
      render json: movs.map { |m| serialize_movimiento(m) }
    end

    private

    def serialize_movimiento(m)
      {
        id: m.id, tipo: m.tipo, cantidad: m.cantidad.to_f, entrada: m.entrada?,
        stock_anterior: m.stock_anterior.to_f, stock_nuevo: m.stock_nuevo.to_f,
        costo_unitario_ars: m.costo_unitario_ars&.to_f, motivo: m.motivo,
        creado_por: m.created_by&.nombre_completo, created_at: m.created_at,
      }
    end

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
      params.require(:bar_producto).permit(:nombre, :categoria, :categoria_producto_id, :precio_ars, :costo_ars, :stock, :stock_minimo, :activo)
    end

    # Unidades vendidas este mes por producto (para la columna "Vend. mes" del panel).
    def vendidos_mes_map
      hoy = Time.zone.today
      ventas_mes = @bar.bar_ventas.where(created_at: hoy.beginning_of_month.beginning_of_day..hoy.end_of_day)
      BarVentaItem.where(club_id: current_user.club_id, bar_venta_id: ventas_mes.select(:id))
                  .group(:bar_producto_id).sum(:cantidad)
    end

    def serialize(p)
      {
        id: p.id, nombre: p.nombre, categoria: p.categoria,
        categoria_producto_id: p.categoria_producto_id,
        categoria_producto_nombre: p.categoria_producto&.nombre,
        precio_ars: p.precio_ars.to_f, costo_ars: p.costo_ars&.to_f,
        stock: p.stock.to_f, stock_minimo: p.stock_minimo.to_f, stock_bajo: p.stock_bajo?,
        valorizado_ars: p.valorizado_ars.to_f,
        margen_pct: p.margen_pct, activo: p.activo,
      }
    end
  end
end
