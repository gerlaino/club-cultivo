module Bar
  # Ventas del bar. Crear venta (POS): admin/supervisor/dispensador. Listado y dashboard
  # analítico: admin/supervisor. Feature flag :bar.
  class VentasController < ApplicationController
    before_action :authenticate_user!
    before_action :require_feature_bar!
    before_action :require_operador, only: [:create]
    before_action :require_gestion,  only: [:index, :dashboard]

    # POST /bar/ventas  { lineas: [{bar_producto_id, cantidad}], medio_pago, turno?, notas? }
    def create
      venta = ::Bar::RegistrarVenta.new(
        current_user.club, current_user,
        lineas:     params[:lineas],
        medio_pago: params[:medio_pago],
        turno:      params[:turno],
        notas:      params[:notas]
      ).call
      render json: serialize(venta), status: :created
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Producto inexistente en la venta' }, status: :unprocessable_entity
    end

    # GET /bar/ventas  (últimas ventas)
    def index
      ventas = current_user.club.bar_ventas.includes(:items, :user).recientes.limit(100)
      render json: ventas.map { |v| serialize(v) }
    end

    # GET /bar/ventas/dashboard  — pulso del bar (hoy por defecto)
    def dashboard
      club  = current_user.club
      hoy   = club.bar_ventas.del_dia(Time.zone.today)

      total   = hoy.sum(:total_ars).to_f
      tickets = hoy.count
      items   = BarVentaItem.where(club_id: club.id, bar_venta_id: hoy.select(:id))

      render json: {
        hoy: {
          total:            total,
          tickets:          tickets,
          ticket_promedio:  tickets.positive? ? (total / tickets).round(2) : 0,
          por_medio_pago:   hoy.group(:medio_pago).sum(:total_ars).transform_values(&:to_f),
          por_hora:         por_hora(hoy),
        },
        top_productos: items.group(:nombre).sum(:cantidad)
                            .sort_by { |_n, c| -c }.first(8)
                            .map { |nombre, cant| { nombre: nombre, cantidad: cant.to_f } },
        reponer: club.bar_productos.activos.stock_bajo.order(:nombre)
                     .map { |p| { id: p.id, nombre: p.nombre, stock: p.stock.to_f, minimo: p.stock_minimo.to_f } },
      }
    end

    private

    # Ventas agrupadas por hora del día (0-23). Devuelve solo las horas con ventas.
    def por_hora(scope)
      scope.group_by { |v| v.created_at.in_time_zone.hour }
           .map { |h, vs| { hora: h, total: vs.sum { |v| v.total_ars.to_f } } }
           .sort_by { |r| r[:hora] }
    end

    def require_feature_bar!
      return if current_user.club.feature?(:bar)

      render json: { error: 'El bar no está habilitado para este club.' }, status: :forbidden
    end

    ROLES_OPERADOR = %w[admin supervisor dispensador].freeze
    ROLES_GESTION  = %w[admin supervisor].freeze

    def require_operador
      render json: { error: 'No autorizado' }, status: :forbidden unless ROLES_OPERADOR.include?(current_user&.role)
    end

    def require_gestion
      render json: { error: 'No autorizado' }, status: :forbidden unless ROLES_GESTION.include?(current_user&.role)
    end

    def serialize(v)
      {
        id: v.id, total_ars: v.total_ars.to_f, medio_pago: v.medio_pago,
        turno: v.turno, notas: v.notas, created_at: v.created_at,
        vendedor: v.user&.first_name || v.user&.email,
        items: v.items.map { |it| { nombre: it.nombre, cantidad: it.cantidad.to_f, precio_unitario_ars: it.precio_unitario_ars.to_f, subtotal_ars: it.subtotal_ars.to_f } },
      }
    end
  end
end
