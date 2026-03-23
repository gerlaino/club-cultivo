# backend/app/controllers/dispensaciones_controller.rb
class DispensacionesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_medico_agricultor_or_admin, except: [:index, :show]
  before_action :set_socio, only: [:index, :create]
  before_action :set_dispensacion, only: [:show, :update, :destroy]

  # GET /socios/:socio_id/dispensaciones
  def index
    @dispensaciones = @socio.dispensaciones
                            .includes(:user, :lote, :indicacion_medica, :sede)
                            .recientes

    cupo_disponible = Dispensacion.cupo_disponible(@socio.id)
    total_mes       = Dispensacion.total_dispensado_mes(@socio.id)

    render json: {
      dispensaciones:       @dispensaciones.map { |d| serialize_dispensacion(d) },
      cupo_mensual:         Dispensacion::CUPO_MENSUAL_GRAMOS,
      total_dispensado_mes: total_mes.to_f.round(2),
      cupo_disponible:      cupo_disponible.to_f.round(2),
    }
  end

  # GET /dispensaciones/:id
  def show
    render json: serialize_dispensacion(@dispensacion)
  end

  # POST /socios/:socio_id/dispensaciones
  def create
    @dispensacion = @socio.dispensaciones.build(dispensacion_params)
    @dispensacion.user = current_user

    # Calcular costo si hay lote con CostoLote registrado
    if @dispensacion.lote_id.present?
      costo_lote = CostoLote.find_by(lote_id: @dispensacion.lote_id)
      if costo_lote&.costo_por_gramo.to_d > 0
        @dispensacion.costo_por_gramo      = costo_lote.costo_por_gramo
        @dispensacion.costo_total_calculado = (costo_lote.costo_por_gramo * @dispensacion.cantidad_gramos).round(2)
      end
    end

    ActiveRecord::Base.transaction do
      @dispensacion.save!

      # Generar MovimientoContable automáticamente
      crear_movimiento_contable(@dispensacion)
    end

    render json: serialize_dispensacion(@dispensacion), status: :created

  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  rescue => e
    render json: { errors: [e.message] }, status: :unprocessable_entity
  end

  # PATCH/PUT /dispensaciones/:id
  def update
    if @dispensacion.update(dispensacion_params_update)
      render json: serialize_dispensacion(@dispensacion)
    else
      render json: { errors: @dispensacion.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /dispensaciones/:id
  def destroy
    @dispensacion.destroy
    head :no_content
  end

  private

  def set_socio
    @socio = current_user.club.socios.find(params[:socio_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Socio no encontrado' }, status: :not_found
  end

  def set_dispensacion
    @dispensacion = Dispensacion.joins(:socio)
                                .where(socios: { club_id: current_user.club_id })
                                .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Dispensación no encontrada' }, status: :not_found
  end

  def dispensacion_params
    params.require(:dispensacion).permit(
      :indicacion_medica_id, :lote_id, :sede_id,
      :cantidad_gramos, :tipo_producto,
      :aporte_socio_ars, :observaciones, :fecha_dispensacion
    )
  end

  # Al editar no permitimos cambiar campos financieros calculados
  def dispensacion_params_update
    params.require(:dispensacion).permit(
      :indicacion_medica_id, :lote_id, :sede_id,
      :tipo_producto, :aporte_socio_ars,
      :observaciones, :fecha_dispensacion
    )
  end

  def require_medico_agricultor_or_admin
    unless current_user.admin? || current_user.medico? || current_user.agricultor?
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end

  def crear_movimiento_contable(dispensacion)
    # Monto del movimiento: aporte del socio si existe, sino costo calculado, sino 0
    monto = if dispensacion.aporte_socio_ars.to_d > 0
              dispensacion.aporte_socio_ars
            elsif dispensacion.costo_total_calculado.to_d > 0
              dispensacion.costo_total_calculado
            else
              return # Sin monto no generamos movimiento
            end

    descripcion = "Dispensación #{dispensacion.cantidad_gramos}g " \
      "#{dispensacion.tipo_producto} — " \
      "#{dispensacion.socio.nombre} #{dispensacion.socio.apellido}"

    MovimientoContable.create!(
      club:             current_user.club,
      sede_id:          dispensacion.sede_id,
      lote_id:          dispensacion.lote_id,
      dispensacion:     dispensacion,
      created_by:       current_user,
      tipo:             "recupero_costo",
      categoria:        "dispensacion",
      descripcion:      descripcion,
      monto_ars:        monto,
      fecha:            dispensacion.fecha_dispensacion,
      pagado:           true,
      medio_pago:       "efectivo",
      comprobante_tipo: "sin_comprobante",
      )
  end

  def serialize_dispensacion(dispensacion)
    {
      id:                     dispensacion.id,
      socio_id:               dispensacion.socio_id,
      socio_nombre:           "#{dispensacion.socio.nombre} #{dispensacion.socio.apellido}",
      usuario: {
        id:     dispensacion.user.id,
        nombre: dispensacion.user.first_name || dispensacion.user.email,
      },
      indicacion_medica: dispensacion.indicacion_medica ? {
        id:        dispensacion.indicacion_medica.id,
        patologia: dispensacion.indicacion_medica.patologia,
      } : nil,
      lote: dispensacion.lote ? {
        id:     dispensacion.lote.id,
        codigo: dispensacion.lote.codigo,
      } : nil,
      sede: dispensacion.sede ? {
        id:     dispensacion.sede.id,
        nombre: dispensacion.sede.nombre,
      } : nil,
      cantidad_gramos:         dispensacion.cantidad_gramos.to_f.round(2),
      tipo_producto:           dispensacion.tipo_producto,
      aporte_socio_ars:        dispensacion.aporte_socio_ars&.to_f,
      costo_por_gramo:         dispensacion.costo_por_gramo&.to_f,
      costo_total_calculado:   dispensacion.costo_total_calculado&.to_f,
      observaciones:           dispensacion.observaciones,
      fecha_dispensacion:      dispensacion.fecha_dispensacion,
      tiene_movimiento_contable: dispensacion.movimiento_contable.present?,
      created_at:              dispensacion.created_at,
      updated_at:              dispensacion.updated_at,
    }
  end
end