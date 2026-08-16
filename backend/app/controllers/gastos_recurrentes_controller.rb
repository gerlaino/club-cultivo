# Catálogo de gastos que se repiten. Se definen acá y se eligen al cargar un movimiento.
#
# Lectura: admin/auditor. Escritura: admin — mismo criterio que las categorías, porque es la
# misma clase de decisión (cómo se clasifica y se carga la plata de la organización).
class GastosRecurrentesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_lectura,   only: [:index]
  before_action :require_escritura, only: [:create, :update, :destroy]
  before_action :set_gasto,         only: [:update, :destroy]

  # GET /gastos_recurrentes?activos=true
  def index
    scope = current_user.club.gastos_recurrentes.includes(:categoria_contable, :sede).ordenados
    scope = scope.activos if params[:activos] == 'true'
    render json: scope.map { |g| serialize(g) }
  end

  def create
    gasto = current_user.club.gastos_recurrentes.build(gasto_params)
    gasto.created_by = current_user
    if gasto.save
      render json: serialize(gasto), status: :created
    else
      render json: { errors: gasto.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @gasto.update(gasto_params)
      render json: serialize(@gasto)
    else
      render json: { errors: @gasto.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # Se borra de verdad (soft-delete): un molde no tiene historia que preservar — los movimientos
  # que se cargaron con él son movimientos comunes y no le quedan colgando.
  def destroy
    @gasto.destroy
    head :no_content
  end

  private

  def set_gasto
    @gasto = current_user.club.gastos_recurrentes.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Gasto recurrente no encontrado' }, status: :not_found
  end

  def gasto_params
    params.require(:gasto_recurrente).permit(
      :nombre, :descripcion, :categoria_contable_id, :sede_id,
      :monto_ars, :cantidad, :unidad, :medio_pago, :proveedor, :activo, :orden
    )
  end

  def require_lectura
    render json: { error: 'No autorizado' }, status: :forbidden unless current_user.admin? || current_user.auditor?
  end

  def require_escritura
    unless current_user.admin?
      render json: { error: 'Solo administradores pueden gestionar los gastos recurrentes' }, status: :forbidden
    end
  end

  def serialize(g)
    {
      id:                    g.id,
      nombre:                g.nombre,
      descripcion:           g.descripcion,
      categoria_contable_id: g.categoria_contable_id,
      categoria_label:       g.categoria_contable&.nombre,
      unidad_negocio_id:     g.unidad_negocio_id,
      sede_id:               g.sede_id,
      sede_nombre:           g.sede&.nombre,
      monto_ars:             g.monto_ars&.to_f,
      cantidad:              g.cantidad&.to_f,
      unidad:                g.unidad,
      medio_pago:            g.medio_pago,
      proveedor:             g.proveedor,
      activo:                g.activo,
      orden:                 g.orden,
    }
  end
end
