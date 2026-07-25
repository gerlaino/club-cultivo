# backend/app/controllers/movimientos_contables_controller.rb
class MovimientosContablesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_lectura,   only: [:index, :show, :dashboard, :export_csv]
  before_action :require_escritura, only: [:create, :update, :destroy, :cerrar_periodo, :reabrir_periodo]
  before_action :set_movimiento,    only: [:show, :update, :destroy]

  # GET /movimientos_contables
  # Params opcionales: desde, hasta, tipo, categoria, sede_id, lote_id, page, per_page
  def index
    scope = current_user.club.movimientos_contables
                        .includes(:sede, :lote, :dispensacion, :created_by, :categoria_contable, :unidad_negocio)
                        .recientes

    scope = scope.where(tipo: params[:tipo])                       if params[:tipo].present?
    scope = scope.where(categoria: params[:categoria])             if params[:categoria].present?
    scope = scope.where(categoria_contable_id: params[:categoria_contable_id]) if params[:categoria_contable_id].present?
    scope = scope.where(unidad_negocio_id: params[:unidad_negocio_id])         if params[:unidad_negocio_id].present?
    scope = scope.por_sede(params[:sede_id])                       if params[:sede_id].present?
    scope = scope.por_lote(params[:lote_id])                       if params[:lote_id].present?

    if params[:desde].present? && params[:hasta].present?
      desde = Date.parse(params[:desde]) rescue nil
      hasta = Date.parse(params[:hasta]) rescue nil
      scope = scope.del_periodo(desde, hasta) if desde && hasta
    elsif params[:mes].present?
      fecha = Date.parse("#{params[:mes]}-01") rescue Date.today
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

  # POST /movimientos_contables/cerrar_periodo  { hasta: 'YYYY-MM-DD' }
  # Congela el libro hasta esa fecha inclusive: nada anterior se puede
  # crear, editar ni borrar. Correcciones = contra-asiento o reapertura.
  def cerrar_periodo
    hasta = Date.parse(params.require(:hasta).to_s)
    return render json: { error: 'La fecha de cierre no puede ser futura' }, status: :unprocessable_entity if hasta > Date.today

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

    if params[:desde].present? && params[:hasta].present?
      desde = Date.parse(params[:desde]) rescue nil
      hasta = Date.parse(params[:hasta]) rescue nil
      scope = scope.del_periodo(desde, hasta) if desde && hasta
    end

    csv_data = generate_csv(scope)

    send_data csv_data,
              filename:    "movimientos_contables_#{Date.today}.csv",
              type:        "text/csv; charset=utf-8",
              disposition: "attachment"
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
      :pagado, :medio_pago, :notas
    )
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
    sede_id  = d[:sede_id].presence || movimiento.sede_id
    cat      = movimiento.categoria_contable
    deposito = club.depositos.find_by(id: d[:deposito_id])
    tipo     = deposito&.clave_sistema == 'cultivo' ? 'cultivo' : 'general'
    insumo   = if d[:insumo_id].present?
                 club.insumos.find(d[:insumo_id])
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
  end

  # Salón: compra de mercadería del bar. Sube el stock del producto y etiqueta el egreso con la
  # sede del bar + unidad "Bar" (para que impacte el P&L del salón). NO es stock de flor seca.
  def aplicar_salon!(movimiento, d)
    club = current_user.club
    bar  = club.bares.find(d[:bar_id])
    producto = if d[:bar_producto_id].present?
                 bar.bar_productos.find(d[:bar_producto_id])
               else
                 bar.bar_productos.create!(club: club, unidad_negocio: bar.unidad_negocio_bar,
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
    movimiento.update!(sede_id: bar.sede_id, unidad_negocio: bar.unidad_negocio_bar)
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

  def serialize(m)
    {
      id:                   m.id,
      tipo:                 m.tipo,
      tipo_label:           m.tipo_label,
      categoria:            m.categoria,
      categoria_label:      m.categoria_contable&.nombre || m.categoria_label,
      categoria_contable_id: m.categoria_contable_id,
      unidad_negocio_id:    m.unidad_negocio_id,
      unidad_negocio:       m.unidad_negocio ? { id: m.unidad_negocio.id, nombre: m.unidad_negocio.nombre, tipo: m.unidad_negocio.tipo } : nil,
      descripcion:          m.descripcion,
      monto_ars:            m.monto_ars.to_f,
      fecha:                m.fecha,
      comprobante_numero:   m.comprobante_numero,
      comprobante_tipo:     m.comprobante_tipo,
      proveedor:            m.proveedor,
      pagado:               m.pagado,
      medio_pago:           m.medio_pago,
      notas:                m.notas,
      sede:                 m.sede ? { id: m.sede.id, nombre: m.sede.nombre } : nil,
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
  def resumen_por_unidad(scope)
    unidades = current_user.club.unidades_negocio.index_by(&:id)
    scope.group(:unidad_negocio_id, :tipo).sum(:monto_ars).each_with_object({}) do |((uid, tipo), total), acc|
      row = acc[uid] ||= begin
        u = uid && unidades[uid]
        { id: uid, nombre: u&.nombre || 'Sin unidad', tipo: u&.tipo, ingresos: 0.0, egresos: 0.0, balance: 0.0 }
      end
      if %w[ingreso recupero_costo].include?(tipo)
        row[:ingresos] += total.to_f
      elsif tipo == 'egreso'
        row[:egresos] += total.to_f
      end
      row[:balance] = (row[:ingresos] - row[:egresos]).round(2)
    end.values.sort_by { |r| -r[:balance] }
  end

  def resumen_por_categoria(scope)
    scope.group(:categoria, :tipo)
         .sum(:monto_ars)
         .map { |(cat, tipo), total| { categoria: cat, tipo: tipo, total: total.to_f } }
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