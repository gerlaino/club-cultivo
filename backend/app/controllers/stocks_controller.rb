class StocksController < ApplicationController
  before_action :authenticate_user!
  before_action :require_lectura_stock!,        only: [:index, :inventario, :show, :movimientos]
  before_action :require_auditor_lectura!,      only: [:trazabilidad]
  before_action :require_escritura_stock!,      only: [:create, :update, :asignar, :ajuste, :descartar, :producir]
  before_action :require_admin_o_supervisor!,   only: [:show_by_qr, :destroy]
  before_action :set_stock, only: [:asignar, :show, :trazabilidad, :update, :ajuste, :descartar, :producir, :movimientos, :destroy]

  # GET /stocks?sede_id=&canal=regulatorio|social&incluir_pendientes=true
  # GET /sedes/:sede_id/stocks
  def index
    sede_id = params[:sede_id]

    if params[:pendientes].present?
      stocks = Stock.joins(:lote).where(lotes: { club_id: current_user.club_id })
                   .pendientes_asignacion.includes(:lote)
      return render json: stocks.map { |s| serialize_stock(s) }
    end

    if params[:historial].present?
      stocks = Stock.where(club_id: current_user.club_id)
                    .includes(:lote, :genetica, :sede)
                    .order(created_at: :desc)
                    .limit(500)
      return render json: stocks.map { |s| serialize_stock(s) }
    end

    if sede_id.present?
      sede   = current_user.club.sedes.find_by(id: sede_id)
      stocks = sede ? sede.stocks.includes(:lote, :genetica).disponibles.asignados.to_a : []
    else
      sede_stocks = current_user.club.sedes
                                .flat_map { |s| s.stocks.includes(:lote, :genetica).disponibles.asignados }
      pool_stocks = Stock.where(club_id: current_user.club_id).includes(:lote, :genetica).disponibles.asignados.del_club.to_a
      stocks = sede_stocks + pool_stocks
    end

    case params[:canal]
    when 'regulatorio' then stocks = stocks.select(&:regulatorio?)
    when 'social'      then stocks = stocks.reject(&:regulatorio?)
    end

    render json: stocks.map { |s| serialize_stock(s) }
  end

  # GET /stocks/inventario — tabla de inventario paginada y filtrable.
  # Filtros: forma_producto, sede_id ('pool' = stock del club sin sede), fecha_desde,
  # fecha_hasta (sobre created_at). Devuelve la página + totales sobre el set FILTRADO
  # (para que los KPIs respeten el filtro).
  def inventario
    scope = Stock.where(club_id: current_user.club_id).where('cantidad > 0')

    scope = scope.where(forma_producto: params[:forma_producto]) if params[:forma_producto].present?
    if params[:sede_id].present?
      scope = params[:sede_id] == 'pool' ? scope.where(sede_id: nil) : scope.where(sede_id: params[:sede_id])
    end
    scope = scope.where('stocks.created_at >= ?', params[:fecha_desde]) if params[:fecha_desde].present?
    scope = scope.where('stocks.created_at <= ?', "#{params[:fecha_hasta]} 23:59:59") if params[:fecha_hasta].present?

    hoy = Date.today
    totales = {
      total_g:             scope.sum(:cantidad).to_f,
      items:               scope.count,
      sedes_con_stock:     scope.where.not(sede_id: nil).distinct.count(:sede_id),
      produccion_propia_g: scope.where(origen: %w[lote derivado_lote]).sum(:cantidad).to_f,
      vencidos:            scope.where('fecha_vencimiento_est < ?', hoy).count,
      por_vencer:          scope.where('fecha_vencimiento_est >= ? AND fecha_vencimiento_est <= ?', hoy, hoy + 30).count,
    }

    page = [params[:page].to_i, 1].max
    per  = (params[:per_page].presence || 25).to_i.clamp(1, 100)
    stocks = scope.includes(:lote, :genetica, :sede)
                  .order(created_at: :desc)
                  .offset((page - 1) * per).limit(per)

    render json: {
      stocks:  stocks.map { |s| serialize_stock(s) },
      meta:    { total: totales[:items], page: page, per_page: per },
      totales: totales,
    }
  end

  # GET /stocks/:id
  def show
    render json: { data: serialize_stock(@stock) }
  end

  # GET /stocks/qr/:codigo_qr — para admin/supervisor al escanear un QR
  def show_by_qr
    stock = Stock.joins(:club)
                 .where(codigo_qr: params[:codigo_qr], club_id: current_user.club_id)
                 .includes(:lote, :sede, lote: :genetica)
                 .first

    return render json: { error: 'Producto no encontrado' }, status: :not_found unless stock

    en_delivery = stock.gramos_reservados

    render json: {
      id:                       stock.id,
      numero_lote_producto:     stock.numero_lote_producto,
      codigo_qr:                stock.codigo_qr,
      forma_producto:           stock.forma_producto,
      unidad:                   stock.unidad,
      cantidad_total:           stock.cantidad.to_f,
      cantidad_disponible_real: stock.cantidad_disponible_real,
      en_delivery_g:            en_delivery,
      fecha_elaboracion:       stock.fecha_elaboracion,
      fecha_vencimiento_est:   stock.fecha_vencimiento_est,
      estado:                  stock.estado,
      lote: stock.lote ? {
        codigo:   stock.lote.codigo,
        genetica: stock.lote.genetica ? {
          nombre:                stock.lote.genetica.nombre,
          numero_registro_inase: stock.lote.genetica.numero_registro_inase,
        } : nil,
      } : nil,
      club: {
        nombre: current_user.club.name,
        logo:   current_user.club.logo.attached? ? url_for(current_user.club.logo) : nil,
      },
      sede: stock.sede ? { nombre: stock.sede.nombre } : nil,
    }
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
    cantidad_anterior = @stock.cantidad.to_f
    if @stock.update(stock_update_params)
      nueva_cantidad = @stock.cantidad.to_f
      if nueva_cantidad != cantidad_anterior
        delta = nueva_cantidad - cantidad_anterior
        @stock.stock_movimientos.create!(
          tipo:    'ajuste',
          gramos:  delta,
          usuario: current_user,
          notas:   "Edición manual: #{cantidad_anterior}g → #{nueva_cantidad}g",
        )
      end
      render json: serialize_stock(@stock.reload)
    else
      render json: { errors: @stock.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # POST /stocks/:id/ajuste
  # Body: { tipo: merma|reconteo|perdida, cantidad_real: float, motivo: string }
  # Se ingresa la cantidad EXACTA actual; el backend calcula el delta a aplicar.
  # (compat: si llega `gramos`, se toma como delta directo.)
  def ajuste
    tipo_ajuste = params[:tipo].presence
    motivo      = params[:motivo].to_s.strip

    return render json: { error: 'Tipo de ajuste inválido' }, status: :unprocessable_entity unless %w[merma reconteo perdida].include?(tipo_ajuste)
    return render json: { error: 'El motivo es obligatorio' }, status: :unprocessable_entity if motivo.blank?

    gramos = if params[:cantidad_real].present?
      params[:cantidad_real].to_f - @stock.cantidad.to_f
    else
      params[:gramos].to_f
    end
    return render json: { error: 'La cantidad ingresada no cambia el stock (delta 0)' }, status: :unprocessable_entity if gramos.zero?

    nueva_cantidad = @stock.cantidad.to_f + gramos
    return render json: { error: "La cantidad resultante sería negativa (#{nueva_cantidad.round(2)}g)" }, status: :unprocessable_entity if nueva_cantidad < 0

    ActiveRecord::Base.transaction do
      @stock.update!(cantidad: nueva_cantidad)
      # Un reconteo redefine la línea base (lo que realmente hay): actualizamos también
      # la cantidad inicial para que "Total" nunca quede por debajo de "Actual". Una merma
      # o pérdida NO toca el inicial (se descuenta de lo que había).
      @stock.update!(cantidad_inicial: nueva_cantidad) if tipo_ajuste == 'reconteo'
      @stock.stock_movimientos.create!(
        tipo:    'ajuste',
        gramos:  gramos,
        usuario: current_user,
        notas:   "[#{tipo_ajuste.upcase}] #{motivo}",
      )
      @stock.update!(estado: 'agotado') if nueva_cantidad == 0
    end
    render json: serialize_stock(@stock.reload)
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # POST /stocks/:id/producir
  # Transforma flor del lote en un producto elaborado (aceite, prensado, etc.): consume
  # gramos del stock de flor y crea un Stock nuevo 'derivado_lote' con su costo derivado
  # (costo por gramo × gramos usados / cantidad producida) y su precio. El descuento de la
  # flor lo hace el modelo (before_create de derivado_lote).
  # Body: { gramos_usados, forma_producto, cantidad_producida, unidad, precio_sugerido_ars? }
  def producir
    unless @stock.forma_producto == 'flor_seca'
      return render json: { error: 'Solo se puede producir desde flor seca' }, status: :unprocessable_entity
    end
    gramos       = params[:gramos_usados].to_f
    cantidad_out = params[:cantidad_producida].to_f
    forma        = params[:forma_producto].to_s
    unidad       = params[:unidad].presence || 'un'

    return render json: { error: 'Indicá los gramos a utilizar (> 0)' }, status: :unprocessable_entity if gramos <= 0
    return render json: { error: 'Indicá la cantidad producida (> 0)' }, status: :unprocessable_entity if cantidad_out <= 0
    return render json: { error: "No hay tantos gramos disponibles (#{@stock.cantidad}g)" }, status: :unprocessable_entity if gramos > @stock.cantidad.to_f
    if forma.blank? || forma == 'flor_seca'
      return render json: { error: 'Elegí el producto resultante (no flor seca)' }, status: :unprocessable_entity
    end

    costo_consumido    = @stock.costo_unitario_ars.to_d * gramos.to_d       # costo por gramo × gramos usados
    costo_unitario_out = cantidad_out.positive? ? (costo_consumido / cantidad_out.to_d).round(2) : nil

    nuevo = nil
    ActiveRecord::Base.transaction do
      # 1) Descontar la flor del stock origen (sea de lote o externo) + movimiento.
      nueva_cant = @stock.cantidad.to_f - gramos
      @stock.update!(cantidad: nueva_cant)
      @stock.update!(estado: 'agotado') if nueva_cant.zero?
      @stock.stock_movimientos.create!(
        tipo: 'produccion', gramos: -gramos, usuario: current_user,
        notas: "[PRODUCCIÓN] #{cantidad_out} #{unidad} de #{forma} (#{gramos}g usados)",
      )

      # 2) Crear el producto elaborado. es_split evita el auto-descuento del modelo
      # (ya descontamos arriba). Hereda el lote si lo hay; si es externo, queda externo.
      nuevo = current_user.club.stocks.new(
        sede_id:                  @stock.sede_id,
        forma_producto:           forma,
        unidad:                   unidad,
        cantidad:                 cantidad_out,
        costo_unitario_ars:       costo_unitario_out,
        precio_sugerido_ars:      params[:precio_sugerido_ars].presence,
        descripcion:              params[:observaciones].presence,
        genetica_id:              @stock.genetica_id,           # hereda la genética del origen
        producido_desde_stock_id: @stock.id,                   # link para revertir al borrar
        lote_origen_consumido_g:  gramos,                      # gramos consumidos del origen
        estado:                   'asignado',
        es_split:                 true,
      )
      if @stock.lote_id
        nuevo.origen  = 'derivado_lote'
        nuevo.lote_id = @stock.lote_id
      else
        nuevo.origen    = 'compra_externa'
        nuevo.proveedor = @stock.proveedor.presence || 'Producción propia'
      end
      nuevo.save!
    end
    render json: serialize_stock(nuevo), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # POST /stocks/:id/descartar
  # Body: { motivo: string }
  def descartar
    motivo = params[:motivo].to_s.strip
    return render json: { error: 'El motivo es obligatorio para descartar stock' }, status: :unprocessable_entity if motivo.blank?
    return render json: { error: 'El stock ya está agotado' }, status: :unprocessable_entity if @stock.agotado?

    gramos_descartados = @stock.cantidad.to_f
    ActiveRecord::Base.transaction do
      @stock.stock_movimientos.create!(
        tipo:    'merma',
        gramos:  -gramos_descartados,
        usuario: current_user,
        notas:   "[FINALIZADO] #{motivo}",
      )
      @stock.update!(cantidad: 0, estado: 'agotado')
    end
    render json: serialize_stock(@stock.reload)
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # DELETE /stocks/:id
  # Borra el stock arrastrando lo reversible (reservas/dispensaciones pendientes con
  # su rollback). Bloquea si hay entregadas o período contable cerrado.
  def destroy
    EliminarStockService.new(stock: @stock, usuario: current_user).eliminar!
    head :no_content
  rescue EliminarStockService::Bloqueado => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # GET /stocks/:id/movimientos
  def movimientos
    movs = @stock.stock_movimientos
                 .includes(:usuario, :sede_origen, :sede_destino)
                 .order(created_at: :desc)
                 .limit(200)
    render json: movs.map { |m|
      {
        id:              m.id,
        tipo:            m.tipo,
        gramos:          m.gramos.to_f,
        notas:           m.notas,
        usuario:         m.usuario ? { id: m.usuario.id, nombre: m.usuario.nombre_completo } : nil,
        sede_origen:     m.sede_origen  ? { id: m.sede_origen.id,  nombre: m.sede_origen.nombre  } : nil,
        sede_destino:    m.sede_destino ? { id: m.sede_destino.id, nombre: m.sede_destino.nombre } : nil,
        created_at:      m.created_at,
      }
    }
  end

  # GET /stocks/:id/trazabilidad
  def trazabilidad
    s = @stock

    # Lote origen
    lote = s.lote

    # Genética — directo en stock o heredada del lote
    genetica = s.genetica || lote&.genetica

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
        id:                 d.id,
        fecha:              d.fecha_dispensacion,
        cantidad_g:         d.cantidad&.to_f,
        paciente_iniciales: "#{d.paciente&.nombre&.[](0)}.#{d.paciente&.apellido&.[](0)}.",
        paciente_dni_last4: d.paciente&.dni_normalizado.to_s.last(4),
      }
    end

    gramos_dispensados  = dispensaciones.sum { |d| d[:cantidad_g].to_f }.round(2)
    cantidad_disponible = s.cantidad.to_f.round(2)
    cantidad_inicial    = (cantidad_disponible + gramos_dispensados).round(2)

    render json: {
      stock: {
        id:                   s.id,
        numero_lote_producto: s.numero_lote_producto,
        forma_producto:       s.forma_producto,
        cantidad_inicial_g:   cantidad_inicial,
        cantidad_disponible_g: cantidad_disponible,
        fecha_elaboracion:    s.fecha_elaboracion,
        codigo_qr:            s.codigo_qr,
        genetica: genetica ? {
          id:                    genetica.id,
          nombre:                genetica.nombre,
          numero_registro_inase: genetica.numero_registro_inase,
          tipo:                  genetica.tipo,
          thc:                   genetica.thc,
          cbd:                   genetica.cbd,
        } : nil,
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
        gramos_dispensados:   gramos_dispensados,
        cantidad_disponible_g: cantidad_disponible,
      },
    }
  end

  # POST /stocks/:id/asignar
  # Body: { sede_id: integer, cantidad?: float }
  # Si cantidad < stock.cantidad → fraccionamiento: crea nuevo stock para esa porción
  def asignar
    unless @stock.pendiente_asignacion? || @stock.asignado?
      return render json: { error: 'Este stock no puede ser asignado' }, status: :unprocessable_entity
    end

    sede_id  = params[:sede_id]
    cantidad = params[:cantidad]&.to_f

    return render json: { error: 'La sede es obligatoria' }, status: :unprocessable_entity if sede_id.blank?

    sede = current_user.club.sedes.find_by(id: sede_id)
    return render json: { error: 'Sede no encontrada' }, status: :not_found unless sede

    cantidad_total = @stock.cantidad.to_f
    es_parcial = cantidad.present? && cantidad > 0 && (cantidad + 0.001) < cantidad_total

    if es_parcial
      ActiveRecord::Base.transaction do
        consumido_proporcional = @stock.lote_origen_consumido_g.present? ?
          (@stock.lote_origen_consumido_g * (cantidad / cantidad_total)).round(2) : nil

        nuevo = Stock.new(
          club_id:                 @stock.club_id,
          lote_id:                 @stock.lote_id,
          pesada_id:               @stock.pesada_id,
          origen:                  @stock.origen,
          forma_producto:          @stock.forma_producto,
          unidad:                  @stock.unidad,
          cantidad:                cantidad,
          sede:                    sede,
          estado:                  'asignado',
          costo_unitario_ars:      @stock.costo_unitario_ars,
          precio_sugerido_ars:     @stock.precio_sugerido_ars,
          genetica_id:             @stock.genetica_id,
          descripcion:             @stock.descripcion,
          proveedor:               @stock.proveedor,
          lote_origen_consumido_g: consumido_proporcional,
        )
        nuevo.es_split = true
        nuevo.save!
        @stock.decrement!(:cantidad, cantidad)
        nuevo.stock_movimientos.create!(
          tipo:            'transferencia',
          gramos:          cantidad,
          sede_destino_id: sede.id,
          usuario:         current_user,
          notas:           "Fraccionado desde #{@stock.numero_lote_producto}",
        )
      end
      render json: serialize_stock(@stock.reload)
    else
      @stock.asignar!(sede: sede, usuario: current_user, notas: params[:notas])
      render json: serialize_stock(@stock.reload)
    end
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
      cantidad_inicial:        s.cantidad_inicial&.to_f,
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
      gramos_reservados:        s.gramos_reservados,
      cantidad_disponible_real: s.cantidad_disponible_real,
      dias_para_vencimiento:    s.dias_para_vencimiento,
      estado_vencimiento:       s.estado_vencimiento,
      created_at:               s.created_at,
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

  def require_admin_o_supervisor!
    render json: { error: 'No autorizado' }, status: :forbidden unless %w[admin supervisor].include?(current_user&.role)
  end
end
