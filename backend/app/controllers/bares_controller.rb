# Bares del club (entidad ligada a una sede social/mixta). Feature flag :bar.
# Ver lista: admin/supervisor/dispensador (para elegir dónde vender). Dashboard: admin/supervisor.
# Alta/edición/borrado: admin. Borrado = soft (recuperable desde la papelera).
class BaresController < ApplicationController
  before_action :authenticate_user!
  before_action :require_feature_bar!
  before_action :require_operador, only: [:index, :show]
  before_action :require_gestion,  only: [:dashboard]
  before_action :require_admin_bar, only: [:create, :update, :destroy]
  before_action :set_bar, only: [:show, :update, :destroy, :dashboard]

  # GET /bares
  def index
    hoy = Time.zone.today
    bares = current_user.club.bares.includes(:sede).order(:nombre)
    render json: bares.map { |b| serialize(b, resultado_mes: b.resultado_periodo(hoy.beginning_of_month, hoy)) }
  end

  # GET /bares/:id
  def show
    render json: serialize(@bar)
  end

  # POST /bares  { bar: { sede_id, nombre, activo } }
  def create
    bar = current_user.club.bares.build(bar_params)
    if bar.save
      render json: serialize(bar), status: :created
    else
      render json: { errors: bar.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /bares/:id
  def update
    if @bar.update(bar_params.except(:sede_id)) # la sede no se cambia una vez creado
      render json: serialize(@bar)
    else
      render json: { errors: @bar.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /bares/:id — soft-delete (recuperable). Si tiene ventas, se recomienda desactivar.
  def destroy
    @bar.update!(deleted_by_id: current_user.id)
    @bar.destroy
    head :no_content
  end

  # GET /bares/:id/dashboard — pulso del bar (resultado del mes + ventas de hoy)
  def dashboard
    hoy   = Time.zone.today
    hoyv  = @bar.bar_ventas.del_dia(hoy)
    total = hoyv.sum(:total_ars).to_f
    items = BarVentaItem.where(club_id: current_user.club_id, bar_venta_id: hoyv.select(:id))

    render json: {
      bar:       serialize(@bar),
      resultado_mes: @bar.resultado_periodo(hoy.beginning_of_month, hoy),
      hoy: {
        total:           total,
        tickets:         hoyv.count,
        ticket_promedio: hoyv.count.positive? ? (total / hoyv.count).round(2) : 0,
        por_medio_pago:  hoyv.group(:medio_pago).sum(:total_ars).transform_values(&:to_f),
      },
      top_productos: items.group(:nombre).sum(:cantidad).sort_by { |_n, c| -c }.first(8)
                          .map { |nombre, cant| { nombre: nombre, cantidad: cant.to_f } },
      reponer: @bar.bar_productos.activos.stock_bajo.order(:nombre)
                   .map { |p| { id: p.id, nombre: p.nombre, stock: p.stock.to_f, minimo: p.stock_minimo.to_f } },
    }
  end

  private

  def set_bar
    @bar = current_user.club.bares.find(params[:id])
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

  def require_admin_bar
    render json: { error: 'Solo el admin gestiona los bares' }, status: :forbidden unless current_user.admin?
  end

  def bar_params
    params.require(:bar).permit(:sede_id, :nombre, :activo)
  end

  def serialize(b, resultado_mes: nil)
    {
      id:     b.id,
      nombre: b.nombre,
      activo: b.activo,
      sede:   b.sede ? { id: b.sede.id, nombre: b.sede.nombre, tipo: b.sede.tipo } : nil,
      resultado_mes: resultado_mes,
    }.compact
  end
end
