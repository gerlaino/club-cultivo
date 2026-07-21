# Depósito de insumos de cultivo (Bloque 2). Feature flag :insumos.
# Lectura: admin/supervisor/cultivador/auditor. Alta de catálogo y compra: admin/supervisor.
# Registro de consumo: admin/supervisor/cultivador (quien usa el insumo en el grow).
class InsumosController < ApplicationController
  before_action :authenticate_user!
  before_action :require_lectura,  only: [:index, :show]
  before_action :require_gestion,  only: [:create, :update, :comprar, :revertir_compra, :reconteo, :destroy]
  before_action :require_consumo,  only: [:consumir]
  before_action :require_gestion,  only: [:transferir]
  before_action :set_insumo,       only: [:show, :update, :comprar, :consumir, :transferir, :revertir_compra, :reconteo, :destroy]

  # GET /insumos?sede_id=<id|pool>&tipo=<cultivo|general>&activos=true
  def index
    scope = current_user.club.insumos.includes(:sede, categoria_contable: :parent)
    scope = scope.activos if params[:activos] == 'true'
    scope = scope.por_tipo(params[:tipo]) if params[:tipo].present?
    scope = scope.de_sede(params[:sede_id]) if params[:sede_id].present?
    render json: {
      insumos:         scope.order(:nombre).map { |i| serialize(i) },
      valorizado_total: scope.sum { |i| i.valorizado_ars }.round(2),
    }
  end

  # GET /insumos/:id
  def show
    render json: serialize(@insumo).merge(
      compras:  @insumo.insumo_compras.order(fecha: :desc).limit(50).map  { |c| serialize_compra(c) },
      consumos: @insumo.insumo_consumos.includes(:lote, :sala).order(fecha: :desc).limit(50).map { |c| serialize_consumo(c) },
    )
  end

  # POST /insumos
  def create
    insumo = current_user.club.insumos.build(insumo_params)
    if insumo.save
      render json: serialize(insumo), status: :created
    else
      render json: { errors: insumo.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /insumos/:id
  def update
    if @insumo.update(insumo_params)
      render json: serialize(@insumo)
    else
      render json: { errors: @insumo.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # POST /insumos/:id/comprar  { cantidad, costo_total_ars, proveedor?, fecha?, sede_id?, generar_egreso? }
  def comprar
    sede = params[:sede_id].present? ? current_user.club.sedes.find_by(id: params[:sede_id]) : nil
    compra = @insumo.registrar_compra!(
      cantidad:        params.require(:cantidad),
      costo_total_ars: params.require(:costo_total_ars),
      proveedor:       params[:proveedor],
      fecha:           params[:fecha].presence || Date.current,
      sede:            sede,
      generar_egreso:  params.fetch(:generar_egreso, true),
      created_by:      current_user
    )
    render json: serialize(@insumo).merge(compra: serialize_compra(compra)), status: :created
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActionController::ParameterMissing => e
    render json: { error: "Falta el parámetro #{e.param}" }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    # Que una validación fallida no explote en 500: devolvemos el motivo real.
    render json: { error: e.record.errors.full_messages.join(', ') }, status: :unprocessable_entity
  end

  # POST /insumos/:id/consumir  { cantidad, lote_ids?: [], lote_id?, sala_id?, fecha?, notas? }
  # Reparte la cantidad en partes iguales entre los lotes indicados (o a una sala / general).
  def consumir
    lote_ids = Array(params[:lote_ids]).presence || Array(params[:lote_id]).reject(&:blank?)
    lotes    = lote_ids.present? ? current_user.club.lotes.where(id: lote_ids).to_a : []
    sala     = params[:sala_id].present? ? current_user.club.salas.find_by(id: params[:sala_id]) : nil

    @insumo.registrar_consumo_repartido!(
      cantidad:   params.require(:cantidad),
      lotes:      lotes,
      sala:       sala,
      fecha:      params[:fecha].presence || Date.current,
      notas:      params[:notas],
      created_by: current_user
    )
    render json: serialize(@insumo), status: :created
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActionController::ParameterMissing => e
    render json: { error: "Falta el parámetro #{e.param}" }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    # Que una validación fallida no explote en 500: devolvemos el motivo real.
    render json: { error: e.record.errors.full_messages.join(', ') }, status: :unprocessable_entity
  end

  # POST /insumos/:id/transferir  { sede_destino_id, cantidad }
  # Mueve una parte del insumo a otra sede (crea el insumo destino si no existe).
  def transferir
    destino_sede = current_user.club.sedes.find_by(id: params[:sede_destino_id])
    return render json: { error: 'Sede destino no encontrada' }, status: :unprocessable_entity unless destino_sede

    destino = @insumo.transferir_a!(
      sede_destino: destino_sede,
      cantidad:     params.require(:cantidad),
      created_by:   current_user
    )
    render json: { origen: serialize(@insumo.reload), destino: serialize(destino) }, status: :created
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActionController::ParameterMissing => e
    render json: { error: "Falta el parámetro #{e.param}" }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    # Que una validación fallida no explote en 500: devolvemos el motivo real.
    render json: { error: e.record.errors.full_messages.join(', ') }, status: :unprocessable_entity
  end

  # POST /insumos/:id/reconteo  { nuevo_stock, motivo: 'correccion'|'merma', notas?, fecha? }
  # Ajusta el stock al conteo físico. 'correccion' = error de carga (sin contable);
  # 'merma' = pérdida real (baja trazable, sin duplicar el egreso de la compra).
  def reconteo
    @insumo.reconciliar_stock!(
      nuevo_stock: params.require(:nuevo_stock),
      motivo:      params.require(:motivo),
      notas:       params[:notas],
      fecha:       params[:fecha].presence || Date.current,
      created_by:  current_user
    )
    render json: serialize(@insumo.reload)
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActionController::ParameterMissing => e
    render json: { error: "Falta el parámetro #{e.param}" }, status: :unprocessable_entity
  end

  # DELETE /insumos/:id
  # Elimina el insumo por completo. Bloquea si ya tuvo consumos (imputados a lotes/salas o merma):
  # en ese caso se desactiva (PATCH activo:false), no se borra. Si solo tuvo compras, revierte sus
  # asientos contables antes de borrar (la plata vuelve).
  def destroy
    if @insumo.insumo_consumos.exists?
      return render json: {
        error: 'Este insumo ya tiene movimientos de salida (consumos o mermas). Desactivalo para conservar el historial, o revertí esos movimientos primero.'
      }, status: :unprocessable_entity
    end
    ActiveRecord::Base.transaction do
      @insumo.insumo_compras.includes(:movimiento_contable).each { |c| c.movimiento_contable&.destroy! }
      @insumo.destroy!
    end
    head :no_content
  end

  # DELETE /insumos/:id/compras/:compra_id
  # Revierte una compra desde la ficha del depósito: baja el stock y borra el asiento contable
  # asociado (la plata "vuelve"). Bloquea si esa mercadería ya se consumió/distribuyó.
  def revertir_compra
    compra = @insumo.insumo_compras.find(params[:compra_id])
    mov    = compra.movimiento_contable
    ActiveRecord::Base.transaction do
      @insumo.revertir_compra!(compra)
      mov&.destroy!
    end
    render json: serialize(@insumo.reload)
  rescue Insumo::Consumido => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Compra no encontrada' }, status: :not_found
  end

  private

  def set_insumo
    @insumo = current_user.club.insumos.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Insumo no encontrado' }, status: :not_found
  end

  ROLES_LECTURA = %w[admin supervisor cultivador auditor].freeze
  ROLES_GESTION = %w[admin supervisor].freeze
  ROLES_CONSUMO = %w[admin supervisor cultivador].freeze

  def require_lectura
    render json: { error: 'No autorizado' }, status: :forbidden unless ROLES_LECTURA.include?(current_user&.role)
  end

  def require_gestion
    render json: { error: 'No autorizado' }, status: :forbidden unless ROLES_GESTION.include?(current_user&.role)
  end

  def require_consumo
    render json: { error: 'No autorizado' }, status: :forbidden unless ROLES_CONSUMO.include?(current_user&.role)
  end

  def insumo_params
    params.require(:insumo).permit(:nombre, :unidad_medida, :stock_minimo, :activo, :categoria_contable_id, :sede_id, :tipo)
  end

  def serialize(i)
    {
      id:                 i.id,
      nombre:             i.nombre,
      unidad_medida:      i.unidad_medida,
      stock_actual:       i.stock_actual.to_f,
      costo_promedio_ars: i.costo_promedio_ars.to_f,
      valorizado_ars:     i.valorizado_ars.to_f,
      stock_minimo:       i.stock_minimo.to_f,
      stock_bajo:         i.stock_bajo?,
      activo:             i.activo,
      tipo:               i.tipo,
      categoria_contable_id: i.categoria_contable_id,
      categoria:          serialize_categoria(i.categoria_contable),
      sede_id:            i.sede_id,
      sede_nombre:        i.sede&.nombre,
    }
  end

  # Categoría del insumo para agrupar en el depósito: madre (grupo) → subcategoría.
  def serialize_categoria(c)
    return nil unless c

    madre = c.parent || c
    hija  = c.parent ? c : nil
    { madre_id: madre.id, madre_nombre: madre.nombre, sub_nombre: hija&.nombre }
  end

  def serialize_compra(c)
    {
      id: c.id, cantidad: c.cantidad.to_f, costo_total_ars: c.costo_total_ars.to_f,
      costo_unitario_ars: c.costo_unitario_ars.to_f, proveedor: c.proveedor,
      fecha: c.fecha, movimiento_contable_id: c.movimiento_contable_id,
    }
  end

  def serialize_consumo(c)
    {
      id: c.id, cantidad: c.cantidad.to_f, costo_imputado_ars: c.costo_imputado_ars.to_f,
      fecha: c.fecha, notas: c.notas,
      lote: c.lote ? { id: c.lote.id, codigo: c.lote.codigo } : nil,
      sala: c.sala ? { id: c.sala.id, nombre: c.sala.nombre } : nil,
    }
  end
end
