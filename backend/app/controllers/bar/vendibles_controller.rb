module Bar
  # Buscador de mercadería vendible por el mostrador del salón, MÁS ALLÁ del depósito Salón:
  # productos del bar + insumos (cultivo/general). Alimenta el buscador del POS cuando lo que se
  # quiere cobrar no vive en el bar (ej. una remera del depósito General).
  #
  # NUNCA devuelve `Stock` — ni propio, ni derivados, ni externo: todo eso sale por dispensación,
  # que es lo que deja la trazabilidad. Dos puertas de salida para el mismo ítem = descuadre.
  # El dispensador solo ve lo que tiene precio cargado (no puede inventar precios).
  class VendiblesController < ApplicationController
    before_action :authenticate_user!
    before_action :require_feature_bar!
    before_action :set_bar
    before_action :require_operador

    ROLES_OPERADOR = %w[admin supervisor dispensador].freeze
    ROLES_GESTION  = %w[admin supervisor].freeze
    LIMITE = 40

    # GET /bares/:bar_id/vendibles?q=texto&otros_depositos=1
    def index
      q = params[:q].to_s.strip
      solo_otros = ActiveModel::Type::Boolean.new.cast(params[:otros_depositos])

      items = []
      items += bar_productos(q) unless solo_otros
      items += insumos(q)

      items = items.reject { |i| i[:precio_ars].to_f <= 0 } unless gestion?
      render json: { resultados: items.sort_by { |i| i[:nombre].to_s.downcase }.first(LIMITE) }
    end

    private

    def gestion? = ROLES_GESTION.include?(current_user&.role)

    def bar_productos(q)
      scope = @bar.bar_productos.where(vendible: true)
      scope = scope.where('nombre ILIKE ?', "%#{q}%") if q.present?
      scope.limit(LIMITE).map { |bp| fila(::Bar::ItemVendible.new(bp)) }
    end

    def insumos(q)
      scope = current_user.club.insumos.activos.where('stock_actual > 0')
      scope = scope.where('nombre ILIKE ?', "%#{q}%") if q.present?
      scope.limit(LIMITE).map { |ins| fila(::Bar::ItemVendible.new(ins)) }
    end

    def fila(item)
      {
        vendible_type: item.tipo, vendible_id: item.id, nombre: item.nombre,
        deposito: item.deposito, unidad: item.unidad,
        disponible: item.disponible.to_f,
        precio_ars: item.precio_sugerido.to_f,
        costo_ars: (gestion? ? item.costo_unitario.to_f : nil),
        requiere_precio: item.precio_sugerido.nil? || item.precio_sugerido <= 0,
      }
    end

    def set_bar
      @bar = current_user.club.bares.find(params[:bar_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Bar no encontrado' }, status: :not_found
    end

    def require_feature_bar!
      return if current_user.club.feature?(:bar)

      render json: { error: 'El bar no está habilitado para este club.' }, status: :forbidden
    end

    def require_operador
      render json: { error: 'No autorizado' }, status: :forbidden unless ROLES_OPERADOR.include?(current_user&.role)
    end
  end
end
