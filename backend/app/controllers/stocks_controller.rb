class StocksController < ApplicationController
  before_action :authenticate_user!
  before_action :require_lectura_stock!,   only: [:index]
  before_action :require_escritura_stock!, only: [:create, :asignar]
  before_action :set_stock, only: [:asignar]

  # GET /stocks?sede_id=&canal=regulatorio|social&incluir_pendientes=true
  # GET /sedes/:sede_id/stocks
  def index
    sede_id = params[:sede_id]

    if params[:pendientes].present?
      stocks = Stock.joins(:lote).where(lotes: { club_id: current_user.club_id })
                   .pendientes_asignacion.includes(:lote)
      return render json: stocks.map { |s| serialize_stock(s) }
    end

    # Stock asignado a sedes
    stocks = current_user.club.sedes
                         .then { |s| sede_id.present? ? s.where(id: sede_id) : s }
                         .flat_map { |sede| sede.stocks.includes(:lote).disponibles.asignados }

    case params[:canal]
    when 'regulatorio' then stocks = stocks.select(&:regulatorio?)
    when 'social'      then stocks = stocks.reject(&:regulatorio?)
    end

    render json: stocks.map { |s| serialize_stock(s) }
  end

  # POST /stocks
  def create
    @stock = Stock.new(stock_params)
    @stock.sede = sede_for_stock

    if @stock.save
      render json: serialize_stock(@stock), status: :created
    else
      render json: { errors: @stock.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # POST /stocks/:id/asignar
  # Body: { sede_id: integer | null }
  def asignar
    unless @stock.pendiente_asignacion?
      return render json: { error: 'Este stock no está pendiente de asignación' }, status: :unprocessable_entity
    end

    sede_id = params[:sede_id]

    if sede_id.present?
      sede = current_user.club.sedes.find_by(id: sede_id)
      return render json: { error: 'Sede no encontrada' }, status: :not_found unless sede
      @stock.asignar!(sede: sede, usuario: current_user, notas: params[:notas])
    else
      # Dejar como "stock del club" (pool para delivery)
      @stock.update!(estado: 'asignado', sede: nil)
      @stock.stock_movimientos.create!(
        tipo:    'transferencia',
        gramos:  @stock.cantidad,
        usuario: current_user,
        notas:   'Asignado como stock del club (pool delivery)',
      )
    end

    render json: serialize_stock(@stock.reload)
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  private

  def stock_params
    params.require(:stock).permit(
      :origen, :lote_id, :lote_origen_consumido_g,
      :forma_producto, :unidad, :cantidad,
      :costo_unitario_ars, :precio_sugerido_ars,
      :proveedor, :descripcion, :categoria, :sede_id, :estado
    )
  end

  def set_stock
    @stock = Stock.where(club_id: current_user.club_id).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Stock no encontrado' }, status: :not_found
  end

  def sede_for_stock
    sid = params.dig(:stock, :sede_id) || params[:sede_id]
    return nil if sid.blank?
    current_user.club.sedes.find(sid)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def serialize_stock(s)
    {
      id:                      s.id,
      club_id:                 s.club_id,
      sede_id:                 s.sede_id,
      estado:                  s.estado,
      origen:                  s.origen,
      lote_id:                 s.lote_id,
      lote_codigo:             s.lote_codigo,
      lote_origen_consumido_g: s.lote_origen_consumido_g&.to_f,
      pesada_id:               s.pesada_id,
      numero_lote_producto:    s.numero_lote_producto,
      codigo_qr:               s.codigo_qr,
      fecha_elaboracion:       s.fecha_elaboracion,
      fecha_vencimiento_est:   s.fecha_vencimiento_est,
      forma_producto:          s.forma_producto,
      unidad:                  s.unidad,
      cantidad:                s.cantidad.to_f,
      costo_unitario_ars:      s.costo_unitario_ars&.to_f,
      precio_sugerido_ars:     s.precio_sugerido_ars&.to_f,
      proveedor:               s.proveedor,
      descripcion:             s.descripcion,
      categoria:               s.categoria,
      regulatorio:             s.regulatorio?,
      del_club:                s.del_club?,
      lote: s.lote ? { id: s.lote.id, codigo: s.lote.codigo, estado: s.lote.estado,
                       genetica: s.lote.genetica ? { nombre: s.lote.genetica.nombre } : nil } : nil,
      created_at:              s.created_at,
    }
  end

  ROLES_LECTURA_STOCK   = %w[admin dispensador manicura].freeze
  ROLES_ESCRITURA_STOCK = %w[admin manicura].freeze

  def require_lectura_stock!
    render json: { error: 'No autorizado' }, status: :forbidden unless ROLES_LECTURA_STOCK.include?(current_user&.role)
  end

  def require_escritura_stock!
    render json: { error: 'No autorizado' }, status: :forbidden unless ROLES_ESCRITURA_STOCK.include?(current_user&.role)
  end
end
