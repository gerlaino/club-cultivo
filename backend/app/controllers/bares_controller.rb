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

  # GET /bares/:id/dashboard — pulso del bar (resultado, caja, ventas por hora, top, lecturas)
  def dashboard
    render json: { bar: serialize(@bar) }.merge(Bar::Pulso.new(bar: @bar).call)
  end

  private

  def set_bar
    @bar = current_user.club.bares.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Bar no encontrado' }, status: :not_found
  end

  # Usa el gating común en vez de uno propio: así el club observado por un super admin también
  # queda cubierto y el 403 llega con el mismo formato que el resto (`requiere_modulo`), que es
  # el que el frontend sabe leer. La versión anterior además reventaba con 500 si el usuario no
  # tenía club — el caso del super admin.
  def require_feature_bar!
    require_feature!(:bar)
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
