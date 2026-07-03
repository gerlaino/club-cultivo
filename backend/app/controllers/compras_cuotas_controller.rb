# Compras financiadas en cuotas: al crear una, se generan N movimientos contables (egresos),
# uno por mes. Ver CompraCuotas.
class ComprasCuotasController < ApplicationController
  before_action :authenticate_user!
  before_action :require_lectura,   only: [:index]
  before_action :require_escritura, only: [:create, :destroy]

  # GET /compras_cuotas
  def index
    compras = current_user.club.compras_cuotas.includes(:sede, :created_by).order(created_at: :desc)
    render json: compras.map { |c| serialize(c) }
  end

  # POST /compras_cuotas
  def create
    compra = current_user.club.compras_cuotas.build(compra_params)
    compra.created_by = current_user
    if compra.save
      render json: serialize(compra), status: :created
    else
      render json: { errors: compra.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /compras_cuotas/:id — borra la compra y todas sus cuotas (movimientos).
  def destroy
    compra = current_user.club.compras_cuotas.find(params[:id])
    if compra.movimientos_contables.any?(&:cerrado?)
      return render json: { error: 'Alguna cuota pertenece a un período contable cerrado y no puede borrarse.' }, status: :unprocessable_entity
    end
    compra.destroy
    head :no_content
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Compra no encontrada' }, status: :not_found
  end

  private

  def require_lectura
    return if current_user.admin? || current_user.role.in?(%w[auditor])
    render json: { error: 'No autorizado' }, status: :forbidden
  end

  def require_escritura
    return if current_user.admin?
    render json: { error: 'Solo administradores pueden registrar compras en cuotas' }, status: :forbidden
  end

  def compra_params
    params.require(:compra_cuotas).permit(
      :sede_id, :descripcion, :categoria, :monto_total_ars, :cuotas_total,
      :fecha_primera_cuota, :medio_pago, :responsable, :proveedor, :notas
    )
  end

  def serialize(c)
    {
      id:                  c.id,
      descripcion:         c.descripcion,
      categoria:           c.categoria,
      monto_total_ars:     c.monto_total_ars.to_f,
      cuotas_total:        c.cuotas_total,
      fecha_primera_cuota: c.fecha_primera_cuota,
      medio_pago:          c.medio_pago,
      responsable:         c.responsable,
      proveedor:           c.proveedor,
      notas:               c.notas,
      sede:                c.sede ? { id: c.sede.id, nombre: c.sede.nombre } : nil,
      cuotas:              c.movimientos_contables.order(:fecha).map { |m|
        { id: m.id, numero: m.cuota_numero, fecha: m.fecha, monto_ars: m.monto_ars.to_f, pagado: m.pagado }
      },
      created_at:          c.created_at,
    }
  end
end
