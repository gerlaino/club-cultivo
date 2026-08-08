class StocksController < ApplicationController
  include DeclaracionInaseGuard
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

    # Contenedores de un lote: usado al confirmar pesajes de manicura para elegir a qué
    # contenedor sumar. Incluye los pendiente_asignacion (recién creados, sin sede), que
    # el listado general excluye. Solo flor_seca: el resto son derivados (inventario).
    if params[:lote_id].present?
      stocks = Stock.where(club_id: current_user.club_id, lote_id: params[:lote_id])
                    .disponibles
                    .where(estado: %w[pendiente_asignacion asignado], forma_producto: 'flor_seca')
                    .includes(:lote, :genetica, :sede)
                    .order(created_at: :desc)
      return render json: stocks.map { |s| serialize_stock(s) }
    end

    # El inventario que se ve es el de las SEDES ASIGNADAS. Un dispensador de la Finca Norte
    # veía —y podía dispensar— el stock de todas las sedes del club: la asignación existe
    # justamente para eso y no la miraba nadie. Quien no tiene sedes asignadas sigue viendo
    # todo (club de una sola sede, o un admin que no se asignó ninguna).
    visibles = current_user.sedes_visibles_ids

    if sede_id.present?
      sede   = current_user.club.sedes.where(id: visibles).find_by(id: sede_id)
      stocks = sede ? sede.stocks.includes(:lote, :genetica).disponibles.asignados.to_a : []
    else
      sede_stocks = current_user.club.sedes.where(id: visibles)
                                .flat_map { |s| s.stocks.includes(:lote, :genetica).disponibles.asignados }
      # El pool (stock sin sede) es del club entero: no pertenece a ninguna sede, así que no
      # hay asignación que lo acote.
      pool_stocks = Stock.where(club_id: current_user.club_id).includes(:lote, :genetica).disponibles.asignados.del_club.to_a
      stocks = sede_stocks + pool_stocks
    end

    case params[:canal]
    when 'regulatorio' then stocks = stocks.select(&:regulatorio?)
    when 'social'      then stocks = stocks.reject(&:regulatorio?)
    end

    # El carrito de dispensa pide solo stock habilitado para dispensar (opt-in). Las vistas
    # de gestión/reporte no pasan el flag y siguen viendo todo el stock.
    stocks = stocks.select(&:apto_dispensa?) if params[:para_dispensa].present?

    render json: stocks.map { |s| serialize_stock(s) }
  end

  # GET /stocks/inventario — tabla de inventario paginada y filtrable.
  # Filtros: forma_producto, sede_id ('pool' = stock del club sin sede), fecha_desde,
  # fecha_hasta (sobre created_at). Devuelve la página + totales sobre el set FILTRADO
  # (para que los KPIs respeten el filtro).
  def inventario
    # Base sin el filtro de forma: los KPIs en gramos se calculan sobre flor seca aunque el
    # usuario esté filtrando por otra forma.
    # Excluimos los 'agotado' (stock finalizado/descartado): el inventario muestra lo que HAY
    # real para usar/dispensar. Un finalizado (cantidad 0, agotado) no va; y si por dato viejo
    # quedó agotado con cantidad > 0, tampoco debe aparecer.
    base = Stock.where(club_id: current_user.club_id).where('cantidad > 0').where.not(estado: 'agotado')
    # Mismo criterio que el listado: sólo el inventario de las sedes asignadas (más el pool,
    # que no es de ninguna sede). La pestaña Stock mostraba el club entero.
    if current_user.limitado_por_sede?
      base = base.where(sede_id: current_user.sedes_visibles_ids + [nil])
    end
    if params[:sede_id].present?
      base = params[:sede_id] == 'pool' ? base.where(sede_id: nil) : base.where(sede_id: params[:sede_id])
    end
    base = base.where('stocks.created_at >= ?', params[:fecha_desde]) if params[:fecha_desde].present?
    base = base.where('stocks.created_at <= ?', "#{params[:fecha_hasta]} 23:59:59") if params[:fecha_hasta].present?

    # Lista + counts: respetan el filtro de forma.
    scope = params[:forma_producto].present? ? base.where(forma_producto: params[:forma_producto]) : base
    # KPI en gramos: SOLO flor seca, y DISPONIBLE REAL (cantidad menos lo reservado/apartado),
    # para que coincida con la columna "Actual" de la tabla. Los derivados (preroll, hash…) son
    # inventario con su propia unidad y no se suman como gramos.
    flor           = base.where(forma_producto: 'flor_seca')
    reservado_flor = Reserva.pendientes.where(stock_id: flor.select(:id)).sum(:cantidad).to_f
    flor_disponible = [flor.sum(:cantidad).to_f - reservado_flor, 0].max

    hoy = Time.zone.today
    totales = {
      total_g:         flor_disponible,
      reservado_g:     reservado_flor,   # flor seca apartada en reservas pendientes
      items:           scope.count,
      sedes_con_stock: scope.where.not(sede_id: nil).distinct.count(:sede_id),
      # Cantidad de ítems de inventario derivado (preroll, hash, aceite…), que no cuentan en
      # los gramos de flor. Reemplaza al KPI redundante de "flor propia".
      derivados_items: base.where.not(forma_producto: 'flor_seca').count,
      vencidos:        scope.where('fecha_vencimiento_est < ?', hoy).count,
      por_vencer:      scope.where('fecha_vencimiento_est >= ? AND fecha_vencimiento_est <= ?', hoy, hoy + 30).count,
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
    attrs = stock_update_params

    # La cantidad inicial de un stock de LOTE no se edita acá: viene de la suma de los pesajes.
    if attrs.key?(:cantidad_inicial) && @stock.origen != 'compra_externa'
      return render json: { error: 'La cantidad inicial de un stock de lote se edita desde el pesaje del lote, no desde acá.' }, status: :unprocessable_entity
    end

    # La cantidad ACTUAL de un stock de lote se cambia con "Ajustar gramos" (deja movimiento), no
    # editando el registro. En stock EXTERNO (prerolls, compra externa) sí se edita directo acá.
    # Solo rechazamos si REALMENTE se intenta cambiar la cantidad de un lote (mandarla igual es no-op:
    # el form de edición manda cantidad siempre, aunque el input no esté visible para lote).
    if attrs.key?(:cantidad) && @stock.origen != 'compra_externa' && attrs[:cantidad].to_f != @stock.cantidad.to_f
      return render json: { error: 'La cantidad de un stock de lote se cambia con "Ajustar gramos", no editando acá.' }, status: :unprocessable_entity
    end

    # El inicial es solo el registro de lo que ingresó: editarlo NO toca el actual (que lo
    # manejan las operaciones y "Ajustar gramos"). Sin movimiento de stock.
    if @stock.update(attrs)
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
      # Un ajuste (reconteo / merma / pérdida) corrige lo que HAY AHORA (cantidad). NO toca el
      # inicial: el inicial es lo que se ingresó al crear y solo cambia editándolo a propósito.
      @stock.update!(cantidad: nueva_cantidad)
      @stock.stock_movimientos.create!(
        tipo:    'ajuste',
        gramos:  gramos,
        usuario: current_user,
        notas:   "[#{tipo_ajuste.upcase}] #{motivo}",
      )
      # El usuario viaja hasta el callback que cierra el lote: el evento de cierre necesita autor.
      @stock.usuario_movimiento = current_user
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
    unless @stock.apto_produccion?
      return render json: { error: 'Este stock no está habilitado para producción' }, status: :unprocessable_entity
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
      # 1) Descontar la flor del stock origen (sea de lote o externo). El "agotado" NO se marca
      #    todavía: marcarlo acá dispara el cierre del lote, y en ese instante el derivado
      #    —que es producto del mismo lote— todavía no existe. Elaborar hash con el último
      #    gramo de flor cerraba el ciclo y a renglón seguido nacían 40 g de hash de un lote
      #    "finalizado". Se marca al final, cuando el derivado ya está en la base (paso 4).
      nueva_cant = @stock.cantidad.to_f - gramos
      @stock.update!(cantidad: nueva_cant)

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

      # 3) Movimiento de producción en el origen, vinculado al derivado: al borrar el derivado
      #    este movimiento se quita del historial (no queda rastro huérfano).
      @stock.stock_movimientos.create!(
        tipo: 'produccion', gramos: -gramos, usuario: current_user,
        stock_resultante: nuevo,
        notas: "[PRODUCCIÓN] #{cantidad_out} #{unidad} de #{forma} (#{gramos}g usados)",
      )

      # 4) Recién ahora: el derivado ya existe, así que si el lote cierra es porque de verdad
      #    no le quedó nada, ni flor ni elaborados.
      @stock.marcar_agotado_si_vacio!(usuario: current_user)
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
      @stock.usuario_movimiento = current_user
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

    # Plantas de origen. El linkeo fino es via la pesada (qué plantas se pesaron a este
    # stock); pero la flor seca no siempre queda atada a una pesada con pesadas_plantas.
    # En ese caso, para producción propia, las plantas de origen son las del lote.
    plantas = []
    if pesada
      plantas = pesada.pesadas_plantas.includes(:plant).map do |pp|
        { id: pp.plant_id, codigo_qr: pp.plant&.codigo_qr, origen: pp.plant&.origen, peso_g: pp.peso_g&.to_f }
      end
    end
    if plantas.empty? && lote
      plantas = lote.plants.map { |p| { id: p.id, codigo_qr: p.codigo_qr, origen: p.origen, peso_g: nil } }
    end

    # Dispensaciones
    dispensaciones = s.dispensaciones.includes(:paciente).order(created_at: :desc).limit(100).map do |d|
      {
        id:                 d.id,
        fecha:              d.fecha_dispensacion,
        cantidad_g:         d.cantidad&.to_f,
        # Nombre completo: la trazabilidad se lee para saber a quién le llegó cada gramo, y
        # dos iniciales no acreditan a nadie. El DNI sigue parcial (últimos cuatro).
        paciente:           d.paciente&.nombre_completo,
        paciente_iniciales: "#{d.paciente&.nombre&.[](0)}.#{d.paciente&.apellido&.[](0)}.",
        paciente_dni_last4: d.paciente&.dni_normalizado.to_s.last(4),
      }
    end

    gramos_dispensados  = dispensaciones.sum { |d| d[:cantidad_g].to_f }.round(2)
    cantidad_disponible = s.cantidad.to_f.round(2)
    cantidad_inicial    = s.cantidad_inicial.to_f.round(2) # verdad única (no reconstruir)

    datos = {
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
          # Informe REGULATORIO: va el nombre con el que el club acredita la variedad ante
          # el organismo. Si declara contra una inscripta, esa es la que corresponde; el
          # nombre real queda en `nombre_propio` para que la traducción sea auditable.
          nombre:                genetica.nombre_declarado,
          nombre_propio:         genetica.nombre,
          declarada:             genetica.declarada_como.present?,
          numero_registro_inase: genetica.numero_inase_declarado,
          tipo:                  genetica.tipo,
          thc:                   genetica.thc,
          cbd:                   genetica.cbd,
        } : nil,
      },
      lote: lote ? {
        id:      lote.id,
        codigo:  lote.codigo,
        estado:  lote.estado,
        genetica: lote.genetica ? { nombre: lote.genetica.nombre_declarado,
                                    nombre_propio: lote.genetica.nombre,
                                    declarada: lote.genetica.declarada_como.present?,
                                    numero_registro_inase: lote.genetica.numero_inase_declarado } : nil,
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

    respond_to do |format|
      format.json { render json: datos }
      # PDF de servidor: la trazabilidad de un lote es lo primero que pide un auditor y se
      # bajaba como captura de pantalla.
      format.pdf do
        # Documento que se presenta: no sale si hay variedades sin acreditar.
        next if bloquear_descarga_si_falta_declarar!

        send_data TrazabilidadDocument.new(club: current_user.club, usuario: current_user, datos: datos).render,
                  filename: "trazabilidad_#{s.numero_lote_producto.presence || s.id}_#{Time.zone.today.strftime('%Y%m%d')}.pdf",
                  type: 'application/pdf', disposition: 'attachment'
      end
    end
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
          disponibilidad:          @stock.disponibilidad,
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
      :cantidad, :cantidad_inicial, :costo_unitario_ars, :precio_sugerido_ars, :descripcion, :proveedor,
      :disponibilidad
    )
  end

  def stock_params
    params.require(:stock).permit(
      :origen, :lote_id, :lote_origen_consumido_g,
      :forma_producto, :unidad, :cantidad,
      :costo_unitario_ars, :precio_sugerido_ars,
      :proveedor, :descripcion, :genetica_id, :categoria, :sede_id, :estado, :disponibilidad
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
      disponibilidad:          s.disponibilidad,
      regulatorio:             s.regulatorio?,
      del_club:                s.del_club?,
      lote: s.lote ? { id: s.lote.id, codigo: s.lote.codigo, estado: s.lote.estado,
                       genetica: s.lote.genetica ? {
                         id:                    s.lote.genetica.id,
                         nombre:                s.lote.genetica.nombre,
                         numero_registro_inase: s.lote.genetica.numero_registro_inase,
                       } : nil } : nil,
      genetica: s.genetica ? { id: s.genetica.id, nombre: s.genetica.nombre } : nil,
      genetica_nombre: (s.genetica || s.lote&.genetica)&.nombre,
      sede:  s.sede  ? { id: s.sede.id, nombre: s.sede.nombre } : nil,
      club:  s.club  ? { id: s.club.id, nombre: s.club.name,
                         logo_url: s.club.logo.attached? ? url_for(s.club.logo) : nil } : nil,
      gramos_reservados:        s.gramos_reservados,
      cantidad_disponible_real: s.cantidad_disponible_real,
      # Lo apartado por eventos EN CURSO: el carrito lo ofrece además del disponible libre, para
      # que el dispensador pueda entregar desde lo reservado del evento que está sucediendo.
      apartados_evento: s.apartados_en_curso.map { |p|
        { evento_id: p.evento_bar_id, evento_nombre: p.evento_bar&.nombre, cantidad: p.saldo_apartado.to_f }
      },
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
