module Bar
  # Ventas de un bar concreto (anidado bajo /bares/:bar_id). Crear venta (POS):
  # admin/supervisor/dispensador. Listar: admin/supervisor. Borrar (revierte stock e ingreso):
  # admin/supervisor. Feature flag :bar. Borrado = soft (recuperable).
  class VentasController < ApplicationController
    before_action :authenticate_user!
    before_action :require_feature_bar!
    before_action :set_bar
    before_action :require_operador, only: [:create]
    before_action :require_gestion,  only: [:index, :destroy]

    # POST /bares/:bar_id/ventas  { lineas: [{bar_producto_id, cantidad}], medio_pago, turno?, notas? }
    def create
      venta = ::Bar::RegistrarVenta.new(
        @bar, current_user,
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

    # GET /bares/:bar_id/ventas
    def index
      ventas = @bar.bar_ventas.includes(:items, :user).recientes.limit(100)
      render json: ventas.map { |v| serialize(v) }
    end

    # DELETE /bares/:bar_id/ventas/:id — soft-delete; el modelo devuelve stock y saca el ingreso.
    def destroy
      venta = @bar.bar_ventas.find(params[:id])
      venta.update!(deleted_by_id: current_user.id)
      venta.destroy
      head :no_content
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Venta no encontrada' }, status: :not_found
    end

    private

    def set_bar
      @bar = current_user.club.bares.find(params[:bar_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Bar no encontrado' }, status: :not_found
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
