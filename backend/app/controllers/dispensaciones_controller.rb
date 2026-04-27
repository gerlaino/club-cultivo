# backend/app/controllers/dispensaciones_controller.rb
class DispensacionesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_medico_agricultor_or_admin, except: [:index, :show]
  before_action :set_socio, only: [:index, :create]
  before_action :set_dispensacion, only: [:show, :update, :destroy]

  # GET /socios/:socio_id/dispensaciones
  def index
    @dispensaciones = @socio.dispensaciones
                            .includes(:user, :lote, :indicacion_medica, :sede, sede_inventario: :genetica)
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
    @dispensacion      = @socio.dispensaciones.build(dispensacion_params)
    @dispensacion.user = current_user
    # Sede se deriva del stock seleccionado, no la elige el operador
    if @dispensacion.sede_inventario && @dispensacion.sede_id.nil?
      @dispensacion.sede_id = @dispensacion.sede_inventario.sede_id
    end

    ActiveRecord::Base.transaction do
      calcular_costo_y_bajar_stock!
      @dispensacion.save!
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
      :indicacion_medica_id, :lote_id, :sede_id, :sede_inventario_id,
      :cantidad_gramos, :tipo_producto, :porcentaje_descuento,
      :aporte_socio_ars, :observaciones, :fecha_dispensacion
    )
  end

  def dispensacion_params_update
    params.require(:dispensacion).permit(
      :indicacion_medica_id, :lote_id, :sede_id, :sede_inventario_id,
      :tipo_producto, :aporte_socio_ars, :porcentaje_descuento,
      :observaciones, :fecha_dispensacion
    )
  end

  def require_medico_agricultor_or_admin
    unless current_user.admin? || current_user.medico? || current_user.agricultor? || current_user.dispensador?
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end

  def calcular_costo_y_bajar_stock!
    inv = @dispensacion.sede_inventario
    return unless inv

    cantidad = @dispensacion.cantidad_gramos.to_d

    raise "Stock insuficiente (disponible: #{inv.stock_gramos}#{inv.unidad_medida})" if inv.stock_gramos < cantidad

    if inv.precio_por_unidad.to_d > 0
      costo_base = (inv.precio_por_unidad * cantidad).round(2)
      descuento  = @dispensacion.porcentaje_descuento.to_d
      costo_final = descuento > 0 ? (costo_base * (1 - descuento / 100)).round(2) : costo_base

      @dispensacion.costo_por_gramo      = inv.precio_por_unidad
      @dispensacion.costo_total_calculado = costo_final
      @dispensacion.aporte_socio_ars    ||= costo_final
    end

    stock_anterior      = inv.stock_gramos.to_f
    inv.stock_gramos   -= cantidad
    inv.save!

    InventarioMovimiento.create!(
      sede:            inv.sede,
      club:            current_user.club,
      sede_inventario: inv,
      dispensacion:    @dispensacion,
      created_by:      current_user,
      tipo:            'egreso_dispensacion',
      cantidad:        -cantidad,
      stock_anterior:  stock_anterior,
      stock_nuevo:     inv.stock_gramos.to_f,
      motivo:          "Dispensación #{@socio.nombre} #{@socio.apellido}"
    )
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
    inv = dispensacion.sede_inventario
    {
      id:           dispensacion.id,
      socio_id:     dispensacion.socio_id,
      socio_nombre: "#{dispensacion.socio.nombre} #{dispensacion.socio.apellido}",
      usuario: {
        id:     dispensacion.user.id,
        nombre: dispensacion.user.first_name || dispensacion.user.email,
      },
      sede: dispensacion.sede ? {
        id:     dispensacion.sede.id,
        nombre: dispensacion.sede.nombre,
      } : nil,
      stock: inv ? {
        id:                inv.id,
        producto_label:    inv.producto_label,
        unidad_medida:     inv.unidad_medida,
        precio_por_unidad: inv.precio_por_unidad&.to_f,
        genetica: inv.genetica ? {
          id:     inv.genetica.id,
          nombre: inv.genetica.nombre,
          tipo:   inv.genetica.tipo,
          thc:    inv.genetica.thc,
          cbd:    inv.genetica.cbd,
        } : nil,
      } : nil,
      cantidad_gramos:         dispensacion.cantidad_gramos.to_f.round(2),
      tipo_producto:           dispensacion.tipo_producto,
      porcentaje_descuento:    dispensacion.porcentaje_descuento&.to_f,
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