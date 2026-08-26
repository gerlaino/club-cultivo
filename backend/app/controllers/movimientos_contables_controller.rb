# backend/app/controllers/movimientos_contables_controller.rb
class MovimientosContablesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_lectura,   only: [:index, :show, :dashboard, :export_csv, :recurrentes]
  before_action :require_escritura, only: [:create, :update, :destroy, :cerrar_periodo, :reabrir_periodo, :registrar_pago]
  before_action :set_movimiento,    only: [:show, :update, :destroy, :registrar_pago]

  # GET /movimientos_contables
  # Params opcionales: desde, hasta, tipo, categoria, sede_id, lote_id, page, per_page
  def index
    scope = current_user.club.movimientos_contables
                        .includes(:sede, :lote, :dispensacion, :created_by, :categoria_contable, :unidad_negocio)
                        .recientes

    scope = scope.where(tipo: params[:tipo])                       if params[:tipo].present?
    scope = scope.where(categoria: params[:categoria])             if params[:categoria].present?
    # Filtrar por una categoría MADRE trae también sus subcategorías: si pedís "Insumos" querés
    # ver lo de Fertilizante y Macetas, no una lista vacía porque los movimientos cuelgan de las
    # hijas. Pedir una subcategoría filtra sólo por ella.
    if params[:categoria_contable_id].present?
      cat_id = params[:categoria_contable_id]
      hijas  = CategoriaContable.where(club_id: current_user.club_id, parent_id: cat_id).pluck(:id)
      scope  = scope.where(categoria_contable_id: [cat_id] + hijas)
    end
    scope = scope.where(unidad_negocio_id: params[:unidad_negocio_id])         if params[:unidad_negocio_id].present?
    scope = scope.por_sede(params[:sede_id])                       if params[:sede_id].present?
    scope = scope.por_lote(params[:lote_id])                       if params[:lote_id].present?

    if params[:desde].present? && params[:hasta].present?
      desde = Date.parse(params[:desde]) rescue nil
      hasta = Date.parse(params[:hasta]) rescue nil
      scope = scope.del_periodo(desde, hasta) if desde && hasta
    elsif params[:mes].present?
      fecha = Date.parse("#{params[:mes]}-01") rescue Time.zone.today
      scope = scope.del_mes(fecha)
    end

    # Las CUOTAS futuras (aún no llegó su mes) no van en el libro ni en los totales: son un
    # compromiso a futuro, no un gasto ocurrido. Aparecen solas cuando llega su fecha. El
    # cronograma completo (incluidas las futuras) se ve en el detalle de la compra en cuotas.
    scope = scope.sin_cuotas_futuras

    # Totales para el período filtrado (antes de paginar)
    totales = calcular_totales(scope)

    # Paginación simple
    per_page = (params[:per_page] || 50).to_i.clamp(1, 200)
    page     = (params[:page] || 1).to_i
    total    = scope.count
    items    = scope.offset((page - 1) * per_page).limit(per_page)

    render json: {
      movimientos: items.map { |m| serialize(m) },
      totales:     totales,
      pagination:  { page: page, per_page: per_page, total: total,
                     total_pages: (total.to_f / per_page).ceil },
    }
  end

  # GET /movimientos_contables/dashboard
  def dashboard
    club  = current_user.club
    hoy   = Time.zone.today
    scope = club.movimientos_contables

    # Filtro por sede si viene el parámetro
    scope = scope.por_sede(params[:sede_id]) if params[:sede_id].present?

    mes_actual  = scope.del_mes(hoy)
    mes_ant     = scope.del_mes(hoy - 1.month)
    anio_actual = scope.del_periodo(hoy.beginning_of_year, hoy)

    # Desglose por sede (siempre, para el breakdown comparativo)
    sedes_del_club = club.sedes.activas.order(:nombre)
    por_sede = sedes_del_club.map do |sede|
      s = club.movimientos_contables.por_sede(sede.id)
      mes = s.del_mes(hoy)
      {
        id:       sede.id,
        nombre:   sede.nombre,
        tipo:     sede.tipo,
        ingresos: mes.ingresos.sum(:monto_ars).to_f,
        egresos:  mes.egresos.sum(:monto_ars).to_f,
        balance:  (mes.ingresos.sum(:monto_ars) - mes.egresos.sum(:monto_ars)).to_f,
        anio: {
          ingresos: s.del_periodo(hoy.beginning_of_year, hoy).ingresos.sum(:monto_ars).to_f,
          egresos:  s.del_periodo(hoy.beginning_of_year, hoy).egresos.sum(:monto_ars).to_f,
          balance:  (s.del_periodo(hoy.beginning_of_year, hoy).ingresos.sum(:monto_ars) -
            s.del_periodo(hoy.beginning_of_year, hoy).egresos.sum(:monto_ars)).to_f,
        }
      }
    end

    # Sin sede asignada
    sin_sede = club.movimientos_contables.where(sede_id: nil)
    mes_sin_sede = sin_sede.del_mes(hoy)
    sin_sede_data = {
      id:       nil,
      nombre:   'Sin sede',
      tipo:     nil,
      ingresos: mes_sin_sede.ingresos.sum(:monto_ars).to_f,
      egresos:  mes_sin_sede.egresos.sum(:monto_ars).to_f,
      balance:  (mes_sin_sede.ingresos.sum(:monto_ars) - mes_sin_sede.egresos.sum(:monto_ars)).to_f,
      anio: {
        ingresos: sin_sede.del_periodo(hoy.beginning_of_year, hoy).ingresos.sum(:monto_ars).to_f,
        egresos:  sin_sede.del_periodo(hoy.beginning_of_year, hoy).egresos.sum(:monto_ars).to_f,
        balance:  (sin_sede.del_periodo(hoy.beginning_of_year, hoy).ingresos.sum(:monto_ars) -
          sin_sede.del_periodo(hoy.beginning_of_year, hoy).egresos.sum(:monto_ars)).to_f,
      }
    }
    por_sede << sin_sede_data if sin_sede_data[:ingresos] > 0 || sin_sede_data[:egresos] > 0

    render json: {
      sede_filtro:  params[:sede_id].presence,
      mes_actual: {
        ingresos:       mes_actual.ingresos.sum(:monto_ars).to_f,
        egresos:        mes_actual.egresos.sum(:monto_ars).to_f,
        balance:        (mes_actual.ingresos.sum(:monto_ars) - mes_actual.egresos.sum(:monto_ars)).to_f,
        por_categoria:  resumen_por_categoria(mes_actual),
        por_semana:     semanas_del_mes(scope, hoy),
      },
      mes_anterior: {
        ingresos: mes_ant.ingresos.sum(:monto_ars).to_f,
        egresos:  mes_ant.egresos.sum(:monto_ars).to_f,
        balance:  (mes_ant.ingresos.sum(:monto_ars) - mes_ant.egresos.sum(:monto_ars)).to_f,
      },
      anio_actual: {
        ingresos: anio_actual.ingresos.sum(:monto_ars).to_f,
        egresos:  anio_actual.egresos.sum(:monto_ars).to_f,
        balance:  (anio_actual.ingresos.sum(:monto_ars) - anio_actual.egresos.sum(:monto_ars)).to_f,
        por_mes:  resumen_por_mes(anio_actual, hoy),
      },
      por_sede:            por_sede,
      # P&L por unidad de negocio del mes en curso (eje analítico ortogonal a la sede)
      por_unidad:          resumen_por_unidad(mes_actual),
      # Deuda real de socios = saldos negativos de cuentas corrientes (caja con deuda visible)
      por_cobrar:          CuentaCorriente.where(club_id: club.id)
                                          .where('saldo_disponible < 0')
                                          .sum('-saldo_disponible').to_f,
      contabilidad_cerrada_hasta: club.contabilidad_cerrada_hasta,
      ultimos_movimientos: scope.sin_cuotas_futuras.recientes.limit(10).map { |m| serialize(m) },
    }
  end

  # GET /movimientos_contables/recurrentes?mes=YYYY-MM
  #
  # Los movimientos FIJOS del club (alquiler, impuestos, servicios, sueldos): los mismos, todos los
  # meses, cargados a mano de cero cada vez. No hay una tabla de "gastos fijos" y a propósito: con
  # inflación el monto cambia casi siempre, así que generarlos solos sería cargar datos falsos. En
  # vez de eso los DETECTAMOS del historial y los ofrecemos prellenados para confirmar.
  #
  # Detección: últimos 6 meses, agrupando por (tipo, categoría, sede, descripción normalizada) y
  # quedándonos con los grupos que aparecen en 2+ meses distintos. Se excluye todo lo que ya tiene
  # automatismo propio (dispensación, ventas del salón, cuotas de una compra financiada): eso no se
  # carga a mano y no es un gasto fijo.
  def recurrentes
    mes   = mes_param
    desde = (mes - 6.months).beginning_of_month

    candidatos = current_user.club.movimientos_contables
                             .includes(:categoria_contable, :sede)
                             .where(fecha: desde...(mes + 1.month).beginning_of_month)
                             .where(dispensacion_id: nil, compra_cuotas_id: nil)
                             .where.not(categoria: 'bar')

    grupos = candidatos.group_by { |m| clave_recurrente(m) }

    fijos = grupos.filter_map do |_clave, movs|
      meses = movs.map { |m| m.fecha.beginning_of_month }.uniq
      next if meses.size < 2 # una sola vez no es un fijo

      del_mes  = movs.find { |m| m.fecha.beginning_of_month == mes }
      previos  = movs.reject { |m| m.fecha.beginning_of_month == mes }
      next if previos.empty? # solo existe el de este mes: todavía no hay historia

      ultimo = previos.max_by(&:fecha)
      serialize_recurrente(ultimo, previos: previos, meses: meses, mes: mes, ya_cargado: del_mes)
    end

    # Primero lo que falta cargar, y dentro de eso lo más caro (que es lo que no se puede olvidar).
    fijos.sort_by! { |f| [f[:ya_cargado] ? 1 : 0, -f[:monto_sugerido]] }

    render json: { mes: mes.strftime('%Y-%m'), fijos: fijos }
  end

  # GET /movimientos_contables/:id
  def show
    render json: serialize(@movimiento)
  end

  # POST /movimientos_contables
  # Además del asiento, un egreso puede llevar un `destino` (depósito/salón) que hace la entrada
  # de stock correspondiente vinculada a ESTE egreso (sin generar un segundo asiento).
  def create
    movimiento = current_user.club.movimientos_contables.build(movimiento_params)
    movimiento.created_by = current_user

    ActiveRecord::Base.transaction do
      movimiento.save!
      aplicar_destino!(movimiento)
    end
    render json: serialize(movimiento), status: :created
  rescue ActiveRecord::RecordInvalid
    render json: { errors: movimiento.errors.full_messages.presence || ['No se pudo guardar'] }, status: :unprocessable_entity
  rescue ArgumentError, ActiveRecord::RecordNotFound => e
    render json: { errors: [e.message] }, status: :unprocessable_entity
  end

  # PATCH /movimientos_contables/:id
  def update
    if @movimiento.dispensacion_id.present?
      return render json: { error: 'Este movimiento fue generado por una dispensación. Para corregirlo, editá o eliminá la dispensación.' }, status: :unprocessable_entity
    end

    # Un aporte de socio ya acreditó su cuenta corriente: cambiarle el monto o el
    # paciente desincronizaría libro y crédito. Se elimina (revierte el crédito) y se recarga.
    if @movimiento.categoria == 'aporte_socio' && @movimiento.paciente_id.present?
      nuevo_monto    = movimiento_params[:monto_ars]
      nuevo_paciente = movimiento_params[:paciente_id]
      monto_cambia    = nuevo_monto.present?    && nuevo_monto.to_d != @movimiento.monto_ars.to_d
      paciente_cambia = nuevo_paciente.present? && nuevo_paciente.to_i != @movimiento.paciente_id
      if monto_cambia || paciente_cambia
        return render json: { error: 'Este aporte ya acreditó la cuenta corriente del socio. Eliminalo (se revierte el crédito) y cargalo de nuevo con los datos correctos.' }, status: :unprocessable_entity
      end
    end

    if @movimiento.update(movimiento_params)
      render json: serialize(@movimiento)
    else
      render json: { errors: @movimiento.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /movimientos_contables/:id
  def destroy
    if @movimiento.dispensacion_id.present?
      return render json: { error: 'Este movimiento fue generado por una dispensación. Eliminá la dispensación para que el libro y el stock queden consistentes.' }, status: :unprocessable_entity
    end

    # Mismo criterio que la dispensación: el ingreso de una venta del salón NO se borra por el
    # libro. Si se borrara solo el asiento, la venta seguiría existiendo y la mercadería NO
    # volvería al depósito (el stock ya salió al cobrar). Se borra la venta, que revierte las dos
    # cosas (BarVenta#revertir_efectos).
    if (venta = current_user.club.bar_ventas.find_by(movimiento_contable_id: @movimiento.id))
      return render json: {
        error: "Este ingreso lo generó la venta ##{venta.id} del salón. Eliminá la venta desde " \
               'Salón → Vender → 🧾 Ventas: así vuelve el stock al depósito y se saca el ingreso del libro.'
      }, status: :unprocessable_entity
    end

    # Una cuota no se borra sola: es parte de una compra financiada. Borrar cualquiera de sus
    # cuotas elimina la COMPRA ENTERA (todas las cuotas), respetando el guard de período cerrado.
    if (compra = @movimiento.compra_cuotas)
      if compra.movimientos_contables.any?(&:cerrado?)
        return render json: { error: 'Alguna cuota pertenece a un período contable cerrado y no puede borrarse.' }, status: :unprocessable_entity
      end
      compra.destroy
      return head :no_content
    end

    # Si el asiento fue una compra de insumo, borrarlo revierte también el stock del insumo
    # (la mercadería vuelve del depósito). Bloquea si ya se consumió/distribuyó (avisa desasignar).
    compra_insumo = InsumoCompra.find_by(movimiento_contable_id: @movimiento.id)
    begin
      ActiveRecord::Base.transaction do
        compra_insumo&.insumo&.revertir_compra!(compra_insumo)
        @movimiento.destroy!
      end
      head :no_content
    rescue Insumo::Consumido => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed => e
      render json: { error: e.record&.errors&.full_messages&.join(', ') || e.message }, status: :unprocessable_entity
    end
  end

  # PATCH /movimientos_contables/:id/registrar_pago  { medio_pago?, fecha_pago? }
  #
  # Saldar una compra que había quedado en "Pendiente de pago". Antes se podía MARCAR la deuda
  # pero no había ninguna forma de decir que se pagó: el gasto quedaba como pendiente para
  # siempre y el total por pagar del club no bajaba nunca.
  #
  # No crea un movimiento nuevo: el egreso ya está asentado desde que se compró. Lo que cambia
  # es su estado de pago —y con eso sale del "a crédito" y entra a la caja del día en que se
  # pagó de verdad.
  def registrar_pago
    if @movimiento.pagado?
      return render json: { error: 'Este movimiento ya figura como pagado.' }, status: :unprocessable_entity
    end
    if @movimiento.cerrado?
      return render json: { error: 'El movimiento pertenece a un período contable cerrado.' },
                    status: :unprocessable_entity
    end

    attrs = { pagado: true }
    attrs[:medio_pago] = params[:medio_pago] if params[:medio_pago].present?

    if @movimiento.update(attrs)
      render json: serialize(@movimiento.reload)
    else
      render json: { errors: @movimiento.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # POST /movimientos_contables/cerrar_periodo  { hasta: 'YYYY-MM-DD' }
  # Congela el libro hasta esa fecha inclusive: nada anterior se puede
  # crear, editar ni borrar. Correcciones = contra-asiento o reapertura.
  def cerrar_periodo
    hasta = Date.parse(params.require(:hasta).to_s)
    # El día en curso NO se puede cerrar: todo asiento automático (venta del salón, dispensación,
    # compra) nace con fecha de hoy y quedaría rechazado por la validación de período cerrado,
    # dejando el mostrador sin poder cobrar. Un período se cierra cuando ya terminó.
    if hasta >= Time.zone.today
      return render json: { error: 'Solo se cierra hasta ayer: el día en curso sigue operando (ventas, dispensaciones y compras se asientan con fecha de hoy).' },
                    status: :unprocessable_entity
    end

    club   = current_user.club
    previo = club.contabilidad_cerrada_hasta
    if previo.present? && hasta < previo
      return render json: { error: "El período ya está cerrado hasta el #{previo.strftime('%d/%m/%Y')}. Usá reabrir para retroceder." }, status: :unprocessable_entity
    end

    club.update!(contabilidad_cerrada_hasta: hasta)
    Auditoria.create!(auditable: club, club: club, user: current_user, accion: 'actualizar',
                      cambios: { 'contabilidad_cerrada_hasta' => [previo&.to_s, hasta.to_s], 'evento' => 'cierre_periodo' })

    render json: { contabilidad_cerrada_hasta: hasta }
  rescue Date::Error, ActionController::ParameterMissing
    render json: { error: 'Fecha inválida' }, status: :unprocessable_entity
  end

  # POST /movimientos_contables/reabrir_periodo  { hasta: 'YYYY-MM-DD' | null }
  def reabrir_periodo
    club   = current_user.club
    previo = club.contabilidad_cerrada_hasta
    nueva  = params[:hasta].present? ? Date.parse(params[:hasta].to_s) : nil

    club.update!(contabilidad_cerrada_hasta: nueva)
    Auditoria.create!(auditable: club, club: club, user: current_user, accion: 'actualizar',
                      cambios: { 'contabilidad_cerrada_hasta' => [previo&.to_s, nueva&.to_s], 'evento' => 'reapertura_periodo' })

    render json: { contabilidad_cerrada_hasta: nueva }
  rescue Date::Error
    render json: { error: 'Fecha inválida' }, status: :unprocessable_entity
  end

  # GET /movimientos_contables/export_csv
  def export_csv
    scope = current_user.club.movimientos_contables.recientes.sin_cuotas_futuras

    desde = hasta = nil
    if params[:desde].present? && params[:hasta].present?
      desde = Date.parse(params[:desde]) rescue nil
      hasta = Date.parse(params[:hasta]) rescue nil
      scope = scope.del_periodo(desde, hasta) if desde && hasta
    end

    respond_to do |format|
      format.csv do
        send_data generate_csv(scope),
                  filename: "movimientos_contables_#{Time.zone.today}.csv",
                  type: "text/csv; charset=utf-8", disposition: "attachment"
      end
      # Excel con tipos reales (montos que suman, fechas que ordenan), totales y filtros.
      # El CSV plano no se podía trabajar sin rearmarlo a mano.
      format.xlsx do
        send_data movimientos_xlsx(scope, desde, hasta),
                  filename: "movimientos_contables_#{Time.zone.today}.xlsx",
                  type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                  disposition: "attachment"
      end
      format.any { send_data generate_csv(scope), filename: "movimientos_contables_#{Time.zone.today}.csv",
                             type: "text/csv; charset=utf-8", disposition: "attachment" }
    end
  end

  private

  def set_movimiento
    @movimiento = current_user.club.movimientos_contables.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Movimiento no encontrado" }, status: :not_found
  end

  def movimiento_params
    params.require(:movimiento_contable).permit(
      :tipo, :categoria, :categoria_contable_id, :unidad_negocio_id,
      :descripcion, :monto_ars, :fecha,
      :sede_id, :lote_id, :dispensacion_id, :paciente_id,
      :comprobante_numero, :comprobante_tipo, :proveedor,
      # Cuánto y de qué: de acá sale el costo unitario. Es del movimiento y no del inventario,
      # porque un gasto que no entra a ningún depósito también se compra por cantidad
      # (10 horas de electricista, 3 análisis de laboratorio).
      :cantidad, :unidad,
      :pagado, :medio_pago, :notas
    )
  end

  # ── Movimientos fijos (detección de recurrentes) ───────────────────────────────

  MESES_ES = %w[enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre
                diciembre].freeze

  def mes_param
    Date.parse("#{params[:mes]}-01")
  rescue ArgumentError, TypeError
    Date.current.beginning_of_month
  end

  # Agrupa por el movimiento "conceptual", no por el texto exacto: "Alquiler julio 2026" y
  # "Alquiler agosto 2026" son el MISMO gasto fijo. Por eso la descripción se normaliza sacándole
  # números y nombres de mes — sin esto justo el naming más común (incluir el mes) no agrupaba nada.
  def clave_recurrente(mov)
    [mov.tipo, mov.categoria_contable_id, mov.categoria, mov.sede_id, descripcion_normalizada(mov.descripcion)]
  end

  def descripcion_normalizada(texto)
    t = I18n.transliterate(texto.to_s.downcase).gsub(/\d+/, ' ')
    MESES_ES.each { |m| t = t.gsub(m, ' ') }
    t.squish
  end

  # Reescribe la descripción del último al mes destino: "Alquiler julio 2026" → "Alquiler agosto 2026".
  # Si no menciona ningún mes, se deja tal cual.
  def descripcion_para_mes(texto, mes)
    nombre_nuevo = MESES_ES[mes.month - 1]
    salida = texto.to_s.gsub(/#{Regexp.union(MESES_ES)}/i) { nombre_nuevo }
    salida = salida.gsub(/\b(20\d{2})\b/, mes.year.to_s) if salida != texto.to_s
    salida
  end

  # Mismo día del mes que la última vez (el alquiler se paga siempre el 5), acotado al largo del mes.
  def fecha_para_mes(fecha_anterior, mes)
    mes.change(day: [fecha_anterior.day, mes.end_of_month.day].min)
  end

  def serialize_recurrente(ultimo, previos:, meses:, mes:, ya_cargado:)
    montos = previos.map { |m| m.monto_ars.to_d }
    {
      # Identidad del grupo (para la key del front): el id del último movimiento del grupo.
      id:                    ultimo.id,
      tipo:                  ultimo.tipo,
      descripcion:           descripcion_para_mes(ultimo.descripcion, mes),
      descripcion_anterior:  ultimo.descripcion,
      monto_sugerido:        montos.last.to_f,
      monto_promedio:        (montos.sum / montos.size).round(2).to_f,
      monto_min:             montos.min.to_f,
      monto_max:             montos.max.to_f,
      fecha_sugerida:        fecha_para_mes(ultimo.fecha, mes),
      ultima_fecha:          ultimo.fecha,
      veces:                 meses.size,
      categoria:             ultimo.categoria,
      categoria_contable_id: ultimo.categoria_contable_id,
      categoria_label:       ultimo.categoria_contable&.nombre || ultimo.categoria_label,
      unidad_negocio_id:     ultimo.unidad_negocio_id,
      sede_id:               ultimo.sede_id,
      sede_nombre:           ultimo.sede&.nombre,
      proveedor:             ultimo.proveedor,
      medio_pago:            ultimo.medio_pago,
      comprobante_tipo:      ultimo.comprobante_tipo,
      ya_cargado:            ya_cargado.present?,
      ya_cargado_id:         ya_cargado&.id,
    }
  end

  # ── Destino del egreso (entrada de stock en un solo paso) ──────────────────────
  # destino: { tipo: 'deposito'|'salon', ...datos }. El egreso ya está creado; acá se hace la
  # entrada de stock vinculada a él, SIN generar otro asiento.
  def aplicar_destino!(movimiento)
    destino = params.dig(:movimiento_contable, :destino)
    return if destino.blank? || movimiento.tipo != 'egreso'

    case destino[:tipo]
    when 'deposito' then aplicar_deposito!(movimiento, destino)
    when 'salon'    then aplicar_salon!(movimiento, destino)
    end
  end

  # Depósito: compra de insumo. Sube stock + recalcula costo promedio; el egreso es este movimiento.
  # El DEPÓSITO lo elige el usuario (entre los del área de la categoría). Un insumo nuevo nace en ese
  # depósito y en una sede (la elegida / la del movimiento). El `tipo` legacy (cultivo/general) se
  # deriva del depósito para compat; la categoría queda linkeada para agrupar por rubro en la vista.
  def aplicar_deposito!(movimiento, d)
    club     = current_user.club
    deposito = club.depositos.find_by(id: d[:deposito_id])
    raise ArgumentError, 'El depósito elegido no existe' if deposito.nil?

    # El depósito es de una SEDE: esa sede manda. No se puede divergir la sede del movimiento de la
    # del depósito (si no, el insumo cae en una sede y el asiento queda en otra).
    sede_id  = deposito.sede_id || d[:sede_id].presence || movimiento.sede_id
    cat      = movimiento.categoria_contable
    tipo     = deposito.clave_sistema == 'cultivo' ? 'cultivo' : 'general'

    insumo   = if d[:insumo_id].present?
                 ins = club.insumos.find(d[:insumo_id])
                 # El insumo vive en UN depósito. Reponer desde otro dejaba el stock en un depósito
                 # (el del insumo) y el asiento en la sede de otro: la plata en una sede y la
                 # mercadería en la otra. El form ya filtra por depósito; esto lo hace cumplir.
                 if ins.deposito_id.present? && ins.deposito_id != deposito.id
                   raise ArgumentError,
                         "«#{ins.nombre}» está en el depósito «#{ins.deposito&.nombre}». " \
                         'Elegí ese depósito, o transferí el insumo antes de reponerlo.'
                 end
                 ins
               else
                 club.insumos.create!(nombre: d[:nombre].to_s.strip,
                                      unidad_medida: d[:unidad_medida].presence || 'unidad',
                                      sede_id: sede_id, tipo: tipo, deposito: deposito,
                                      categoria_contable: cat)
               end
    cantidad = d[:cantidad].to_d
    raise ArgumentError, 'Indicá la cantidad de insumo' if cantidad <= 0

    compra = insumo.registrar_compra!(
      cantidad: cantidad, costo_total_ars: movimiento.monto_ars, created_by: current_user,
      proveedor: movimiento.proveedor, fecha: movimiento.fecha, generar_egreso: false
    )
    compra.update!(movimiento_contable: movimiento)
    # El asiento queda en la sede del depósito (aunque el form haya mandado otra).
    movimiento.update!(sede_id: sede_id) if sede_id.present? && movimiento.sede_id != sede_id
  end

  # Salón: compra de mercadería del bar. Sube el stock del producto y etiqueta el egreso con la
  # sede del bar + unidad "Bar" (para que impacte el P&L del salón). NO es stock de flor seca.
  def aplicar_salon!(movimiento, d)
    club = current_user.club
    bar  = club.bares.find(d[:bar_id])
    # Si vino el depósito Salón, su sede y la del bar tienen que ser la misma: si no, había dos
    # autoridades sobre la sede del asiento (el depósito la fijaba y después el bar la pisaba).
    if d[:deposito_id].present?
      dep = club.depositos.find_by(id: d[:deposito_id])
      if dep&.sede_id.present? && bar.sede_id != dep.sede_id
        raise ArgumentError, "El bar «#{bar.nombre}» no es de la sede del depósito «#{dep.nombre}»."
      end
    end
    producto = if d[:bar_producto_id].present?
                 bar.bar_productos.find(d[:bar_producto_id])
               else
                 bar.bar_productos.create!(club: club, unidad_negocio: bar.unidad_negocio_bar,
                                           deposito: bar.deposito_salon, # lo linkeamos al depósito Salón de su sede
                                           vendible: !ActiveModel::Type::Boolean.new.cast(d[:no_vender]), # "no vender" → fuera del catálogo POS
                                           nombre: d[:nombre].to_s.strip, categoria: d[:categoria].presence || 'bebida',
                                           precio_ars: d[:precio_ars].to_d)
               end
    cantidad = d[:cantidad].to_d
    raise ArgumentError, 'Indicá la cantidad de mercadería' if cantidad <= 0

    # Compra real: sube stock Y recalcula el costo promedio (igual que "Comprar" desde el bar y
    # que aplicar_deposito! para insumos). Este movimiento ES el egreso (generar_egreso: false para
    # no duplicarlo); antes solo bumpeaba stock y dejaba el margen sin costo.
    compra = producto.registrar_compra!(cantidad: cantidad, costo_total_ars: movimiento.monto_ars,
                                        created_by: current_user, proveedor: movimiento.proveedor,
                                        generar_egreso: false)
    compra.update!(movimiento_contable: movimiento)
    # El egreso es del salón: sede del bar + unidad "Bar" + categoría "Bar / Salón" (para que
    # el rollup por categoría no lo mezcle en "Otro" y el P&L del salón lo tome).
    movimiento.update!(sede_id: bar.sede_id, unidad_negocio: bar.unidad_negocio_bar, categoria: 'bar')
  end

  def require_lectura
    unless current_user.admin? || current_user.role.in?(%w[auditor])
      render json: { error: "No autorizado" }, status: :forbidden
    end
  end

  def require_escritura
    unless current_user.admin?
      render json: { error: "Solo administradores pueden crear o modificar movimientos contables" }, status: :forbidden
    end
  end

  # Mapa sede_id → bar_id (memoizado por request) para linkear un asiento del bar a su salón.
  def bar_id_por_sede(sede_id)
    return nil if sede_id.nil?

    (@bares_por_sede ||= current_user.club.bares.pluck(:sede_id, :id).to_h)[sede_id]
  end

  # El depósito no es una columna del movimiento: se llega por la compra de insumo que generó.
  # `@depositos_por_movimiento` lo precarga de una para el listado (si no, es un N+1 por fila).
  def deposito_de(m)
    @depositos_por_movimiento ||= begin
      compras = InsumoCompra.where.not(movimiento_contable_id: nil).includes(insumo: :deposito)
      compras.each_with_object({}) do |c, acc|
        dep = c.insumo&.deposito
        acc[c.movimiento_contable_id] = { id: dep.id, nombre: dep.nombre } if dep
      end
    end
    @depositos_por_movimiento[m.id]
  end

  def serialize(m)
    {
      id:                   m.id,
      tipo:                 m.tipo,
      tipo_label:           m.tipo_label,
      categoria:            m.categoria,
      # `categoria_label` mostraba el nombre de la categoría contable a secas, así que para una
      # SUBcategoría decía "Kawsay" bajo el rótulo "Categoría" — el nombre de la subcategoría
      # presentado como si fuera la categoría, y sin la madre por ningún lado.
      # Ahora van los tres datos por separado, y el que quiera la ruta usa `categoria_ruta`.
      categoria_label:      m.categoria_ruta || m.categoria_label,
      categoria_madre:      m.categoria_madre_nombre,
      subcategoria:         m.subcategoria_nombre,
      categoria_ruta:       m.categoria_ruta,
      categoria_contable_id: m.categoria_contable_id,
      es_bar:               m.categoria == 'bar',
      bar_id:               m.categoria == 'bar' ? bar_id_por_sede(m.sede_id) : nil,
      unidad_negocio_id:    m.unidad_negocio_id,
      unidad_negocio:       m.unidad_negocio ? { id: m.unidad_negocio.id, nombre: m.unidad_negocio.nombre, tipo: m.unidad_negocio.tipo } : nil,
      descripcion:          m.descripcion,
      monto_ars:            m.monto_ars.to_f,
      cantidad:             m.cantidad&.to_f,
      unidad:               m.unidad,
      # Calculado, nunca guardado: si se guardara, corregir el monto o la cantidad dejaría un
      # unitario viejo que no se corresponde con ninguno de los dos.
      costo_unitario_ars:   m.costo_unitario_ars&.to_f,
      fecha:                m.fecha,
      comprobante_numero:   m.comprobante_numero,
      comprobante_tipo:     m.comprobante_tipo,
      proveedor:            m.proveedor,
      pagado:               m.pagado,
      medio_pago:           m.medio_pago,
      notas:                m.notas,
      sede:                 m.sede ? { id: m.sede.id, nombre: m.sede.nombre } : nil,
      # A qué depósito entró la compra, para el listado. Sale por la compra de insumo que el
      # alta creó; un gasto común no entra a ningún inventario y devuelve nil (la vista muestra
      # "Sin depósito", que es un dato, no un hueco).
      deposito:             deposito_de(m),
      lote:                 m.lote ? { id: m.lote.id, codigo: m.lote.codigo } : nil,
      dispensacion_id:      m.dispensacion_id,
      paciente_id:          m.paciente_id,
      paciente:             m.paciente ? { id: m.paciente.id, nombre: m.paciente.nombre_completo } : nil,
      created_by:           m.created_by&.first_name || m.created_by&.email,
      created_at:           m.created_at,
      updated_at:           m.updated_at,
      cerrado:              m.cerrado?,
      compra_cuotas_id:     m.compra_cuotas_id,
      cuota_numero:         m.cuota_numero,
    }
  end

  def calcular_totales(scope)
    {
      ingresos:  scope.ingresos.sum(:monto_ars).to_f,
      egresos:   scope.egresos.sum(:monto_ars).to_f,
      balance:   (scope.ingresos.sum(:monto_ars) - scope.egresos.sum(:monto_ars)).to_f,
      a_credito: scope.a_credito.sum(:monto_ars).to_f,
      count:     scope.count,
    }
  end

  # Ingresos/egresos/resultado agrupados por unidad de negocio. Los movimientos sin unidad
  # asignada caen en un grupo "Sin unidad" (id nil), para que el total siempre cuadre.
  # P&L por unidad de negocio (área), con el desglose por sede adentro de cada una (matriz área × sede).
  # `sedes:` permite ver, para un mismo área, cuánto aporta cada sede sin perder el total agregado.
  def resumen_por_unidad(scope)
    unidades = current_user.club.unidades_negocio.index_by(&:id)
    sedes    = current_user.club.sedes.index_by(&:id)
    acc = {}
    # Se agrupa TAMBIÉN por `pagado`: un ingreso sin cobrar no es plata que entró.
    #
    # Una dispensación a cuenta corriente crea su asiento con `pagado: false` —correcto: la
    # entrega ocurrió y queda registrada— pero esta suma lo metía en `ingresos` igual, así que el
    # P&L mostraba plata que todavía nadie pagó. `MovimientoContable.ingresos` ya excluía lo no
    # cobrado; acá se agrupaba por `tipo` a mano y se salteaba el scope.
    #
    # No se descarta: va a `a_cobrar`, porque esconderlo haría parecer que la venta no existió.
    # Los EGRESOS siguen contándose estén pagados o no, igual que el scope `egresos`: se reconoce
    # lo que se debe y sólo lo que se cobró. Es la convención conservadora del proyecto.
    scope.group(:unidad_negocio_id, :sede_id, :tipo, :pagado).sum(:monto_ars).each do |(uid, sede_id, tipo, pagado), total|
      u   = uid && unidades[uid]
      row = acc[uid] ||= { id: uid, nombre: u&.nombre || 'Sin unidad', tipo: u&.tipo,
                           ingresos: 0.0, egresos: 0.0, a_cobrar: 0.0, balance: 0.0, sedes: {} }
      s    = sede_id && sedes[sede_id]
      srow = row[:sedes][sede_id || 0] ||= { id: sede_id, nombre: s&.nombre || 'Sin sede',
                                             ingresos: 0.0, egresos: 0.0, a_cobrar: 0.0, balance: 0.0 }
      if %w[ingreso recupero_costo].include?(tipo)
        destino = pagado ? :ingresos : :a_cobrar
        row[destino] += total.to_f; srow[destino] += total.to_f
      elsif tipo == 'egreso'
        row[:egresos] += total.to_f; srow[:egresos] += total.to_f
      end
      row[:balance]  = (row[:ingresos] - row[:egresos]).round(2)
      srow[:balance] = (srow[:ingresos] - srow[:egresos]).round(2)
    end
    acc.values.each { |r| r[:sedes] = r[:sedes].values.sort_by { |x| -x[:balance] } }
        .sort_by { |r| -r[:balance] }
  end

  # Agrupa por la categoría EDITABLE, no por el string legacy `categoria`.
  #
  # Agrupar por el string mostraba "Otro" para casi todo: `sincronizar_desde_categoria_contable`
  # lo completa con `clave_efectiva` y cae en 'otro' para cualquier categoría que la organización
  # creó ella misma —o sea, todas las suyas—. El panel decía "Otro $120.000" mientras el listado
  # de abajo, que sí lee la categoría contable, mostraba "Fertilizantes › Kawsay".
  #
  # Se agrupa por la MADRE: en un panel de un mes, "Fertilizantes" es la línea que se lee; el
  # desglose por subcategoría es otra pregunta y vive en el libro diario.
  def resumen_por_categoria(scope)
    cats = CategoriaContable.with_deleted
                            .where(id: scope.distinct.pluck(:categoria_contable_id).compact)
                            .index_by(&:id)

    scope.group(:categoria_contable_id, :categoria, :tipo)
         .sum(:monto_ars)
         .each_with_object(Hash.new(0.0)) do |((cat_id, legacy, tipo), total), acc|
           cat    = cats[cat_id]
           madre  = cat&.parent || cat
           nombre = madre&.nombre || MovimientoContable::CATEGORIA_LABELS[legacy] || legacy
           acc[[nombre, tipo]] += total.to_f
         end
         .map { |(nombre, tipo), total| { categoria: nombre, tipo: tipo, total: total } }
         .sort_by { |r| -r[:total] }
  end

  def semanas_del_mes(scope, hoy)
    inicio = hoy.beginning_of_month
    fin    = hoy
    result = []
    semana_num = 1
    d = inicio
    while d <= fin
      d_fin = [d.end_of_week, fin].min
      s = scope.del_periodo(d, d_fin)
      result << {
        label:    "Sem #{semana_num}",
        ingresos: s.ingresos.sum(:monto_ars).to_f,
        egresos:  s.egresos.sum(:monto_ars).to_f,
      }
      d = d_fin + 1.day
      semana_num += 1
    end
    result
  end

  def resumen_por_mes(scope, hoy)
    (1..hoy.month).map do |mes|
      fecha   = Date.new(hoy.year, mes, 1)
      sub     = scope.del_mes(fecha)
      ing     = sub.ingresos.sum(:monto_ars).to_f
      egr     = sub.egresos.sum(:monto_ars).to_f
      { mes: mes, mes_label: I18n.l(fecha, format: "%B"), ingresos: ing, egresos: egr, balance: ing - egr }
    end
  end

  def movimientos_xlsx(scope, desde, hasta)
    movs = scope.includes(:sede, :lote, :created_by).to_a
    # El signo en el monto es lo que hace que el total del Excel sea el resultado real y no
    # una suma de valores absolutos.
    ingresos = movs.select { |m| m.tipo == 'ingreso' }.sum { |m| m.monto_ars.to_f }
    egresos  = movs.select { |m| m.tipo == 'egreso'  }.sum { |m| m.monto_ars.to_f }

    XlsxExport.new(
      club:   current_user.club,
      titulo: 'Movimientos contables',
      subtitulo: (desde && hasta) ? "Período #{desde.strftime('%d/%m/%Y')} — #{hasta.strftime('%d/%m/%Y')}" : 'Todos los movimientos',
      resumen: {
        'Ingresos'  => ingresos,
        'Egresos'   => -egresos,
        'Resultado' => ingresos - egresos,
      },
      headers: ['Fecha', 'Tipo', 'Sector', 'Categoría', 'Descripción', 'Monto', 'Sede', 'Lote',
                'Comprobante', 'Proveedor', 'Pagado', 'Medio de pago', 'Notas', 'Cargado por'],
      formatos: [:fecha, :texto, :texto, :texto, :texto, :moneda, :texto, :texto,
                 :texto, :texto, :texto, :texto, :texto, :texto],
      totales: [5],
      rows: movs.map { |m|
        [
          m.fecha, m.tipo_label, m.unidad_negocio&.nombre, m.categoria_label, m.descripcion,
          m.tipo == 'egreso' ? -m.monto_ars.to_f : m.monto_ars.to_f,
          m.sede&.nombre, m.lote&.codigo,
          [m.comprobante_tipo, m.comprobante_numero].compact_blank.join(' '),
          m.proveedor, (m.pagado ? 'Sí' : 'No'), m.medio_pago, m.notas,
          m.created_by&.nombre_completo.presence || m.created_by&.email,
        ]
      },
    ).render
  end

  def generate_csv(scope)
    require "csv"
    headers = %w[
      ID Fecha Tipo Categoría Descripción Monto_ARS Sede Lote
      Comprobante_Nro Comprobante_Tipo Proveedor Pagado Medio_Pago Notas Creado_por
    ]
    CSV.generate(col_sep: ";", encoding: "UTF-8") do |csv|
      csv << headers
      scope.each do |m|
        csv << [
          m.id, m.fecha, m.tipo_label, m.categoria_label, m.descripcion,
          m.monto_ars.to_f, m.sede&.nombre, m.lote&.codigo,
          m.comprobante_numero, m.comprobante_tipo, m.proveedor,
          m.pagado ? "Sí" : "No", m.medio_pago, m.notas,
          m.created_by&.first_name || m.created_by&.email,
        ]
      end
    end
  end
end