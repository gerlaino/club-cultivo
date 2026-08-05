module Bar
  # Productos de un bar concreto (anidado bajo /bares/:bar_id). Lectura y reposición:
  # admin/supervisor/dispensador. Alta/edición/borrado de catálogo: admin. Feature flag :bar.
  # Borrado = soft (recuperable desde la papelera).
  class ProductosController < ApplicationController
    before_action :authenticate_user!
    before_action :require_feature_bar!
    before_action :set_bar
    # `comprar` (con costo) SÍ es del mostrador: si entró mercadería, la carga quien la recibió.
    # Deja stock, costo promedio y su egreso contable con `created_by`, así que hay registro de
    # quién y cuánto. `reponer` en cambio subía cantidad SIN costo y SIN asiento —mercadería que
    # aparece de la nada, con el margen mintiendo—: eso queda para la gestión, y para corregir
    # un conteo está `ajustar`.
    before_action :require_operador,  only: [:index, :movimientos, :codigo_barras, :comprar]
    before_action :require_gestion,   only: [:reponer]
    before_action :require_admin_bar, only: [:create, :update, :destroy, :ajustar]
    before_action :set_producto, only: [:update, :destroy, :reponer, :comprar, :ajustar, :movimientos, :codigo_barras]

    # GET /bares/:bar_id/productos
    def index
      scope = @bar.bar_productos.includes(:categoria_producto)
      scope = scope.activos if params[:activos] == 'true'
      # El dispensador solo ve lo VENDIBLE: si no lo puede vender, no es su responsabilidad verlo.
      scope = scope.where(vendible: true) unless gestion?
      vendidos = vendidos_mes_map
      render json: scope.order(:categoria, :nombre).map { |p| serialize(p).merge(vendidos_mes: vendidos[p.id].to_f) }
    end

    # POST /bares/:bar_id/productos
    # Alta unificada: crea el producto y, si viene `carga_inicial` (cantidad + costo), registra la
    # primera compra en la misma transacción (sube stock + costo promedio + egreso "Bar / Salón").
    # Así el alta es un solo paso: de la nada a producto listo para vender, sin ir a Comprar.
    def create
      carga = params[:carga_inicial]
      ActiveRecord::Base.transaction do
        prod = @bar.bar_productos.create!(producto_params.merge(club: current_user.club, unidad_negocio: @bar.unidad_negocio_bar, deposito: @bar.deposito_salon))
        if carga.present? && carga[:cantidad].to_d.positive?
          prod.registrar_compra!(cantidad: carga[:cantidad], costo_total_ars: carga[:costo_total_ars],
                                 proveedor: carga[:proveedor].presence, created_by: current_user)
        end
        render json: serialize(prod.reload), status: :created
      end
    rescue ActiveRecord::RecordInvalid => e
      render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # PATCH /bares/:bar_id/productos/:id
    def update
      if @producto.update(producto_params)
        render json: serialize(@producto)
      else
        render json: { errors: @producto.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PATCH /bares/:bar_id/productos/:id/codigo_barras  { codigo_barras }
    # El dispensador puede asignar o corregir el código de barras: es el que está en el
    # mostrador con el producto y el lector. Deliberadamente NO pasa por `producto_params`,
    # que permite precio, costo y stock — esos siguen siendo del admin.
    def codigo_barras
      valor = params[:codigo_barras].to_s.strip.presence

      if @producto.update(codigo_barras: valor)
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

    def require_gestion
      render json: { error: 'No autorizado' }, status: :forbidden unless gestion?
    end

    def require_admin_bar
      render json: { error: 'Solo el admin configura los productos del bar' }, status: :forbidden unless current_user.admin?
    end

    def gestion? = %w[admin supervisor].include?(current_user&.role)

    def producto_params
      params.require(:bar_producto).permit(:nombre, :categoria, :categoria_producto_id, :precio_ars, :costo_ars, :stock, :stock_minimo, :activo, :codigo_barras, :vendible)
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
        codigo_barras: p.codigo_barras,
        categoria_producto_id: p.categoria_producto_id,
        categoria_producto_nombre: p.categoria_producto&.nombre,
        precio_ars: p.precio_ars.to_f, costo_ars: p.costo_ars&.to_f,
        stock: p.stock.to_f, stock_minimo: p.stock_minimo.to_f, stock_bajo: p.stock_bajo?,
        valorizado_ars: p.valorizado_ars.to_f,
        margen_pct: p.margen_pct, activo: p.activo, vendible: p.vendible,
      }
    end
  end
end
