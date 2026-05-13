class StocksController < ApplicationController
  before_action :authenticate_user!
  before_action :require_lectura_stock!,   only: [:index, :show]
  before_action :require_auditor_lectura!, only: [:trazabilidad]
  before_action :require_escritura_stock!, only: [:create, :update, :asignar]
  before_action :set_stock, only: [:asignar, :show, :trazabilidad, :update]

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
                         .flat_map { |sede| sede.stocks.includes(:lote, :genetica).disponibles.asignados }

    case params[:canal]
    when 'regulatorio' then stocks = stocks.select(&:regulatorio?)
    when 'social'      then stocks = stocks.reject(&:regulatorio?)
    end

    render json: stocks.map { |s| serialize_stock(s) }
  end

  # GET /stocks/:id
  def show
    render json: { data: serialize_stock(@stock) }
  end

  # POST /stocks
  def create
    @stock = Stock.new(stock_params)
    @stock.sede  = sede_for_stock
    @stock.club  = current_user.club

    if @stock.save
      render json: serialize_stock(@stock), status: :created
    else
      render json: { errors: @stock.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /stocks/:id
  def update
    if @stock.update(stock_update_params)
      render json: serialize_stock(@stock.reload)
    else
      render json: { errors: @stock.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /stocks/:id/trazabilidad
  def trazabilidad
    s = @stock

    # Lote origen
    lote = s.lote

    # Pesada origen
    pesada = s.pesada

    # Plantas pesadas (via pesadas_plantas)
    plantas = []
    if pesada
      plantas = pesada.pesadas_plantas.includes(:plant).map do |pp|
        { id: pp.plant_id, codigo_qr: pp.plant&.codigo_qr, peso_g: pp.peso_g&.to_f }
      end
    end

    # Dispensaciones
    dispensaciones = s.dispensaciones.includes(:paciente).order(created_at: :desc).limit(100).map do |d|
      {
        id:                d.id,
        fecha:             d.fecha_dispensacion,
        cantidad_g:        d.cantidad&.to_f,
        paciente_iniciales: "#{d.paciente&.nombre&.[](0)}.#{d.paciente&.apellido&.[](0)}.",
        paciente_dni_last4: d.paciente&.dni_normalizado.to_s.last(4),
      }
    end

    render json: {
      stock: {
        id:                   s.id,
        numero_lote_producto: s.numero_lote_producto,
        forma_producto:       s.forma_producto,
        cantidad_g:           s.cantidad&.to_f,
        fecha_elaboracion:    s.fecha_elaboracion,
        codigo_qr:            s.codigo_qr,
      },
      lote: lote ? {
        id:      lote.id,
        codigo:  lote.codigo,
        estado:  lote.estado,
        genetica: lote.genetica ? { nombre: lote.genetica.nombre, numero_registro_inase: lote.genetica.numero_registro_inase } : nil,
      } : nil,
      pesada: pesada ? {
        id:             pesada.id,
        fase_destino:   pesada.fase_destino,
        peso_total_g:   pesada.peso_total_g&.to_f,
        registrado_at:  pesada.registrado_at,
        plantas_count:  plantas.size,
      } : nil,
      plantas:        plantas,
      dispensaciones: dispensaciones,
      totales: {
        plantas_origen:       plantas.size,
        dispensaciones_count: dispensaciones.size,
        gramos_dispensados:   dispensaciones.sum { |d| d[:cantidad_g].to_f }.round(2),
      },
    }
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

  def stock_update_params
    params.require(:stock).permit(
      :cantidad, :costo_unitario_ars, :precio_sugerido_ars, :descripcion, :proveedor
    )
  end

  def stock_params
    params.require(:stock).permit(
      :origen, :lote_id, :lote_origen_consumido_g,
      :forma_producto, :unidad, :cantidad,
      :costo_unitario_ars, :precio_sugerido_ars,
      :proveedor, :descripcion, :genetica_id, :categoria, :sede_id, :estado
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
                       genetica: s.lote.genetica ? {
                         id:                    s.lote.genetica.id,
                         nombre:                s.lote.genetica.nombre,
                         numero_registro_inase: s.lote.genetica.numero_registro_inase,
                       } : nil } : nil,
      genetica: s.genetica ? { id: s.genetica.id, nombre: s.genetica.nombre } : nil,
      sede:  s.sede  ? { id: s.sede.id, nombre: s.sede.nombre } : nil,
      club:  s.club  ? { id: s.club.id, nombre: s.club.name,
                         logo_url: s.club.logo.attached? ? url_for(s.club.logo) : nil } : nil,
      created_at:              s.created_at,
    }
  end

  ROLES_LECTURA_STOCK   = %w[admin supervisor dispensador manicura].freeze
  ROLES_ESCRITURA_STOCK = %w[admin supervisor manicura].freeze
  ROLES_AUDITOR_LECTURA = %w[admin auditor supervisor].freeze

  def require_lectura_stock!
    render json: { error: 'No autorizado' }, status: :forbidden unless ROLES_LECTURA_STOCK.include?(current_user&.role)
  end

  def require_escritura_stock!
    render json: { error: 'No autorizado' }, status: :forbidden unless ROLES_ESCRITURA_STOCK.include?(current_user&.role)
  end

  def require_auditor_lectura!
    render json: { error: 'No autorizado' }, status: :forbidden unless ROLES_AUDITOR_LECTURA.include?(current_user&.role)
  end
end
