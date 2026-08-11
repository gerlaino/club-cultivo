class InformesController < ApplicationController
  include DeclaracionInaseGuard
  before_action :authenticate_user!
  before_action :require_auditor_o_admin!

  PERIODO_RANGOS = {
    'mes_actual'   => -> { [Time.zone.today.beginning_of_month, Time.zone.today.end_of_month] },
    'mes_anterior' => -> { [1.month.ago.beginning_of_month, 1.month.ago.end_of_month] },
    'trimestre'    => -> { [3.months.ago.beginning_of_month, Time.zone.today.end_of_month] },
    'anio'         => -> { [Time.zone.today.beginning_of_year, Time.zone.today.end_of_year] },
  }.freeze

  def reprocann
    data = reprocann_data(current_user.club)

    respond_to do |format|
      format.json { render json: data }
      format.pdf do
        pdf = ReprocannDocument.new(club: current_user.club, usuario: current_user, data: data).render
        send_data pdf,
                  filename:    "informe_reprocann_#{Time.zone.today.strftime('%Y%m%d')}.pdf",
                  type:        "application/pdf",
                  disposition: "attachment"
      end
      format.xlsx do
        send_data reprocann_xlsx(current_user.club, data),
                  filename:    "informe_reprocann_#{Time.zone.today.strftime('%Y%m%d')}.xlsx",
                  type:        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                  disposition: "attachment"
      end
    end
  end

  # Un informe se define una sola vez (KPIs + tablas) y de esa definición salen la respuesta
  # JSON, el PDF y el Excel. Antes el PDF era una captura de pantalla con html2canvas y el
  # Excel no existía.
  # `resena`: en una o dos frases, qué pregunta contesta este informe y con qué criterio está
  # armado. Un informe que no dice de qué habla obliga a adivinar a partir de los números —y con
  # dos informes que cortan el mismo dato distinto, adivinar termina en "esto no coincide".
  def responder_informe(titulo:, datos:, kpis:, secciones:, nombre:, periodo: nil, nota: nil,
                        resena: nil, exige_declaracion_inase: false)
    respond_to do |format|
      format.json { render json: datos.merge(resena: resena) }
      format.pdf do
        next if exige_declaracion_inase && bloquear_descarga_si_falta_declarar!

        pdf = InformeDocument.new(club: current_user.club, usuario: current_user, titulo: titulo,
                                  kpis: kpis, secciones: secciones, periodo: periodo, nota: nota).render
        send_data pdf, filename: "#{nombre}_#{Time.zone.today.strftime('%Y%m%d')}.pdf",
                  type: 'application/pdf', disposition: 'attachment'
      end
      format.xlsx do
        next if exige_declaracion_inase && bloquear_descarga_si_falta_declarar!

        principal = secciones.first || { headers: [], rows: [] }
        xlsx = XlsxExport.new(
          club: current_user.club, titulo: titulo, subtitulo: periodo,
          headers: principal[:headers], rows: principal[:rows],
          formatos: principal[:formatos], totales: principal[:totales],
          resumen: kpis.to_h { |k| [k[:label], k[:valor]] },
        ).render
        send_data xlsx, filename: "#{nombre}_#{Time.zone.today.strftime('%Y%m%d')}.xlsx",
                  type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                  disposition: 'attachment'
      end
    end
  end

  def produccion
    club  = current_user.club
    desde, hasta = periodo_rango

    total_lotes   = club.lotes.count
    lotes_activos = club.lotes.where.not(estado: %w[finalizado]).count
    lotes_cosechados = club.lotes.where(estado: 'finalizado')
                           .where(updated_at: desde..hasta).count

    # Los gramos del período salen del RENDIMIENTO DEL LOTE, que es lo que llena el flujo de
    # manicura al cerrar el curado (`Lote#check_and_finalize_manicura!`). Antes se sumaban
    # `Pesada.peso_curado_g` con `fase_destino: 'finalizado'`: una tabla que en la práctica
    # está vacía —la organización pesa por PesajeManicura, no por Pesada— así que el informe mostraba
    # "0 gramos producidos" con veinte lotes curados a la vista.
    #
    # La fecha del lote es la de su paso a curado (cuando el producto existe); si ese evento
    # no está, se usa `updated_at`, que es lo mejor disponible.
    gramos_producidos = gramos_del_periodo(club, desde, hasta)

    plantas_totales = Plant.joins(lote: :sala).where(salas: { sede_id: club.sede_ids })
                           .where.not(state: %w[cosechado finalizado]).count

    # Agregados por estado. Las PLANTAS se cuentan igual que el KPI de arriba: plantas que
    # están en pie, no `lotes.plants_count`. Ese campo es el declarado histórico —incluye las
    # cosechadas y las de lotes ya cerrados— así que la tabla sumaba 548 mientras el KPI
    # "Plantas en pie" del mismo informe decía 156. Un informe no puede contradecirse solo.
    lotes_por_estado = club.lotes.group(:estado).count
    plantas_por_estado = Plant.joins(lote: :sala)
                              .where(salas: { sede_id: club.sede_ids })
                              .where.not(state: %w[cosechado finalizado])
                              .group('lotes.estado').count
    por_estado = Lote::ESTADOS.filter_map do |e|
      next if (lotes_e = lotes_por_estado[e].to_i).zero?

      # Rendimiento ACUMULADO de los lotes que hoy están en ese estado (sin filtro de fecha:
      # la tabla habla del presente, no del período).
      { estado: e, lotes: lotes_e, plantas: plantas_por_estado[e].to_i,
        rendimiento: club.lotes.where(estado: e).sum(:rendimiento_real_g).to_f.round(1) }
    end

    # El informe de Sedes era este mismo dato partido en otra pantalla: plantas y flor por
    # sede, con el MISMO criterio de conteo que el KPI de acá. Un club de una sola sede abría
    # un informe de una fila. Vive como desglose de Producción, que es de lo que habla.
    por_sede = club.sedes.includes(:salas).map do |s|
      plantas = Plant.joins(lote: :sala).where(salas: { sede_id: s.id })
                     .where.not(state: %w[cosechado finalizado]).count
      # Flor seca solamente: los derivados (hash, preroll) tienen su propia unidad y no se
      # suman como gramos.
      flor = Stock.where(sede_id: s.id, forma_producto: 'flor_seca').disponibles.sum(:cantidad).to_f
      { id: s.id, nombre: s.nombre, salas: s.salas.cultivo.count,
        plantas: plantas, stock_disponible: flor.round(1) }
    end

    datos = {
      total_lotes:      total_lotes,
      lotes_activos:    lotes_activos,
      lotes_cosechados: lotes_cosechados,
      gramos_producidos: gramos_producidos,
      plantas_totales:  plantas_totales,
      por_estado:       por_estado,
      por_sede:         por_sede,
      total_sedes:      por_sede.size,
    }

    responder_informe(
      titulo: 'Informe de producción', nombre: 'informe_produccion',
      resena: 'Cuánto produjo la organización y cómo viene el cultivo. Arriba, lo cosechado en el período elegido; abajo, la foto de HOY: qué lotes y plantas hay en cada estado ahora mismo, con el rendimiento acumulado de cada uno.',
      datos: datos, periodo: etiqueta_periodo(desde, hasta),
      kpis: [
        { label: 'Lotes totales',   valor: total_lotes },
        { label: 'Lotes activos',   valor: lotes_activos, tono: :ok },
        { label: 'Cosechados',      valor: lotes_cosechados },
        { label: 'Cosechado en el período', valor: gramos_producidos.round(1) },
        { label: 'Plantas en pie',  valor: plantas_totales },
      ],
      secciones: [
        {
          # LA FOTO DE HOY, no del período: estos lotes están en ese estado AHORA. Antes esta
          # tabla traía una columna "Gramos" filtrada por el período elegido, así que un lote
          # curado el mes pasado aparecía con 0 g al lado —dos marcos temporales en la misma
          # pantalla, y el de abajo contradecía al de arriba—. Los gramos del período están en
          # el KPI y en su propia sección; acá va el rendimiento acumulado de cada lote, que es
          # lo que ese lote realmente tiene.
          titulo: 'Hoy en el cultivo',
          headers: ['Estado', 'Lotes', 'Plantas', 'Rendimiento acumulado'],
          rows: por_estado.map { |e| [e[:estado].to_s.tr('_', ' ').capitalize, e[:lotes], e[:plantas], e[:rendimiento]] },
          formatos: [:texto, :numero, :numero, :numero],
          totales: [1, 2, 3],
          aligns: { 1 => :right, 2 => :right, 3 => :right },
        },
        {
          titulo: 'Por sede',
          headers: ['Sede', 'Salas', 'Plantas', 'Flor seca (g)'],
          rows: por_sede.map { |s| [s[:nombre], s[:salas], s[:plantas], s[:stock_disponible]] },
          formatos: [:texto, :numero, :numero, :numero],
          totales: [1, 2, 3],
          aligns: { 1 => :right, 2 => :right, 3 => :right },
          vacio: 'La organización todavía no tiene sedes cargadas.',
        },
      ],
    )
  end

  def dispensaciones
    club  = current_user.club
    desde, hasta = periodo_rango

    disps = Dispensacion.no_canceladas.joins(stock: :sede)
                        .where(sedes: { club_id: club.id })
                        .where(fecha_dispensacion: desde..hasta)

    total  = disps.count
    gramos = disps.sum(:cantidad).to_f
    pax    = disps.select(:paciente_id).distinct.count
    promedio = total.positive? ? (gramos / total).round(2) : 0

    # Nombre y apellido completos. Estaba con iniciales "para no exponer datos personales",
    # pero quien abre este informe (admin o auditor de la organización) ya puede ver la ficha entera del
    # paciente: la inicial no protegía nada y volvía el informe ilegible — con dos "G.L." no
    # se sabe de quién se habla ni se puede cruzar con nada.
    # Con qué se lo identifica y QUÉ se le entregó. Sólo el nombre y los gramos no alcanza
    # para cruzar este informe con producción ni para acreditar a nadie: el DNI parcial
    # desambigua homónimos y la genética/forma es lo que permite seguir el producto.
    resumen = disps.includes(:paciente, stock: :lote).group_by(&:paciente_id).map do |_, ds|
      p = ds.first.paciente
      formas    = ds.filter_map { |d| d.stock&.forma_producto }.uniq
      geneticas = ds.filter_map { |d| d.genetica_nombre.presence || d.stock&.genetica&.nombre ||
                                      d.stock&.lote&.genetica&.nombre }.uniq
      {
        paciente:     p.nombre_completo,
        dni_ultimos_3: p.dni_normalizado.to_s.last(3),
        iniciales:    "#{p.nombre[0]}.#{p.apellido[0]}.",   # se mantiene por compatibilidad
        geneticas:    geneticas,
        formas:       formas,
        cantidad:     ds.size,
        total_gramos: ds.sum { |d| d.cantidad.to_f }.round(2),
        ultima_fecha: ds.max_by(&:fecha_dispensacion)&.fecha_dispensacion,
      }
    end.first(100)

    datos = {
      total_dispensaciones:    total,
      gramos_dispensados:      gramos,
      pacientes_atendidos:     pax,
      promedio_por_dispensacion: promedio,
      resumen_anonimizado:     resumen,
    }

    responder_informe(
      titulo: 'Informe de dispensaciones', nombre: 'informe_dispensaciones',
      resena: 'Qué salió de la organización y hacia quién, en el período elegido. Una fila por paciente, con el DNI parcial para identificarlo sin ambigüedad y la genética y forma de lo que retiró — que es lo que permite cruzar este informe con producción.',
      datos: datos, periodo: etiqueta_periodo(desde, hasta),
      kpis: [
        { label: 'Entregas',           valor: total },
        { label: 'Gramos dispensados', valor: gramos.round(1), tono: :ok },
        { label: 'Pacientes',          valor: pax },
        { label: 'Promedio por entrega', valor: promedio },
      ],
      secciones: [{
        titulo: 'Detalle por paciente',
        headers: ['Paciente', 'DNI', 'Genética', 'Producto', 'Entregas', 'Gramos', 'Última entrega'],
        rows: resumen.map { |r|
          [r[:paciente], "***#{r[:dni_ultimos_3]}",
           r[:geneticas].any? ? r[:geneticas].join(', ') : '—',
           r[:formas].map { |f| f.to_s.tr('_', ' ') }.join(', ').presence || '—',
           r[:cantidad], r[:total_gramos], fmt_fecha(r[:ultima_fecha])]
        },
        formatos: [:texto, :texto, :texto, :texto, :numero, :numero, :texto],
        totales: [4, 5],
        aligns: { 4 => :right, 5 => :right },
      }],
      nota: 'Contiene datos personales de pacientes: tratar como información sensible.',
    )
  end

  def sedes
    club  = current_user.club
    sedes = club.sedes.includes(:salas)

    por_sede = sedes.map do |s|
      plantas = Plant.joins(lote: :sala).where(salas: { sede_id: s.id })
                     .where.not(state: %w[cosechado finalizado]).count
      # "Stock disponible (g)" = flor seca solamente. Los derivados (preroll, hash…) son
      # inventario con su propia unidad y no se suman como gramos de flor.
      stock_g = Stock.joins(:sede).where(sede: s, forma_producto: 'flor_seca').disponibles.sum(:cantidad).to_f rescue 0
      {
        nombre:          s.nombre,
        salas:           s.salas.cultivo.count,
        plantas:         plantas,
        stock_disponible: stock_g,
      }
    end

    sedes_activas  = sedes.where(activa: true).count rescue sedes.count
    salas_totales  = sedes.sum { |s| s.salas.cultivo.count }
    plantas_totales = por_sede.sum { |r| r[:plantas] }

    datos = {
      total_sedes:    sedes.count,
      sedes_activas:  sedes_activas,
      salas_totales:  salas_totales,
      plantas_totales: plantas_totales,
      por_sede:       por_sede,
    }

    responder_informe(
      titulo: 'Informe de sedes', nombre: 'informe_sedes', datos: datos,
      resena: 'Cómo está repartido el cultivo entre las sedes: salas, plantas en pie y flor seca disponible en cada una.',
      kpis: [
        { label: 'Sedes',    valor: sedes.count },
        { label: 'Activas',  valor: sedes_activas, tono: :ok },
        { label: 'Salas',    valor: salas_totales },
        { label: 'Plantas',  valor: plantas_totales },
      ],
      secciones: [{
        titulo: 'Detalle por sede',
        headers: ['Sede', 'Salas', 'Plantas', 'Flor seca (g)'],
        rows: por_sede.map { |r| [r[:nombre], r[:salas], r[:plantas], r[:stock_disponible]] },
        formatos: [:texto, :numero, :numero, :numero],
        totales: [1, 2, 3],
        aligns: { 1 => :right, 2 => :right, 3 => :right },
      }],
    )
  end

  def cumplimiento
    club = current_user.club
    desde, hasta = periodo_rango

    # Sólo la población activa, y con las mismas categorías excluyentes del informe
    # REPROCANN: la tasa de cumplimiento no puede pasar de 100% ni contar bajas.
    pacientes = Paciente.for_club(club.id).where(es_paciente: true)
    conteos = Hash.new(0)
    pacientes.pluck(:reprocann_estado, :reprocann_numero, :reprocann_vencimiento).each do |e, n, v|
      conteos[Paciente.reprocann_categoria(estado: e, numero: n, vencimiento: v)] += 1
    end
    con_vigente  = conteos['vigente']
    vencen_30d   = conteos['por_vencer']
    vencidos     = conteos['vencido']
    sin_seg      = pacientes.where(con_seguimiento_medico: false).count

    total_pax = conteos.values.sum
    # Quien vence en 20 días HOY está en regla: cuenta como cumplimiento, aunque tenga alerta.
    en_regla = con_vigente + vencen_30d
    tasa = total_pax.positive? ? ((en_regla.to_f / total_pax) * 100).round(1) : 0

    # Socios SIN número REPROCANN que dispensaron en el período (no es un "límite": no existe
    # tope de gramos — es un indicador de cumplimiento regulatorio).
    disp_sin_reprocann = Dispensacion
      .joins(:paciente, stock: :sede)
      .where(sedes: { club_id: club.id })
      .where(pacientes: { reprocann_numero: nil })
      .where(fecha_dispensacion: desde..hasta)
      .distinct.count(:paciente_id)

    alertas = []
    if vencidos > 0
      alertas << { tipo: 'reprocann_vencido', severidad: 'error',
                   iniciales: '—', detalle: "#{vencidos} pacientes con REPROCANN vencido" }
    end
    if vencen_30d > 0
      alertas << { tipo: 'reprocann_por_vencer', severidad: 'warning',
                   iniciales: '—', detalle: "#{vencen_30d} pacientes vencen en ≤30 días" }
    end
    if sin_seg > 0
      alertas << { tipo: 'sin_seguimiento', severidad: 'warning',
                   iniciales: '—', detalle: "#{sin_seg} pacientes sin seguimiento médico" }
    end

    datos = {
      pacientes_con_reprocann_vigente: con_vigente,
      reprocann_vencen_30d:            vencen_30d,
      reprocann_vencidos:              vencidos,
      dispensaciones_sin_reprocann:    disp_sin_reprocann,
      tasa_cumplimiento:               tasa,
      alertas:                         alertas,
    }

    responder_informe(
      titulo: 'Informe de cumplimiento', nombre: 'informe_cumplimiento',
      resena: 'Qué tan al día está la población de pacientes con su REPROCANN y qué alertas hay abiertas.',
      datos: datos, periodo: etiqueta_periodo(desde, hasta),
      kpis: [
        { label: 'Tasa de cumplimiento', valor: "#{tasa}%", tono: tasa >= 90 ? :ok : :warn },
        { label: 'Con REPROCANN vigente', valor: con_vigente, tono: :ok },
        { label: 'Vencen en ≤30 días',    valor: vencen_30d, tono: :warn },
        { label: 'Vencidos',              valor: vencidos,   tono: :crit },
      ],
      secciones: [{
        titulo: 'Alertas',
        headers: ['Severidad', 'Detalle'],
        rows: alertas.map { |a| [a[:severidad] == 'error' ? 'Crítica' : 'Atención', a[:detalle]] },
        vacio: 'Sin alertas: la población está en regla.',
        col_widths: nil,
      }],
      nota: "Pacientes sin número de REPROCANN que recibieron una entrega en el período: #{disp_sin_reprocann}.",
    )
  end

  def plan_vs_real
    club = current_user.club
    lotes = club.lotes.where.not(rendimiento_objetivo_g: nil)
                      .or(club.lotes.where.not(plants_count_objetivo: nil))
                      .order(created_at: :desc)
                      .limit(50)

    detalle = lotes.map do |l|
      desv_rendimiento = if l.rendimiento_objetivo_g.present? && l.rendimiento_real_g.present?
        ((l.rendimiento_real_g.to_f - l.rendimiento_objetivo_g.to_f) / l.rendimiento_objetivo_g.to_f * 100).round(1)
      end
      desv_plantas = if l.plants_count_objetivo.present? && l.plants_count_cosechadas.present?
        ((l.plants_count_cosechadas.to_f - l.plants_count_objetivo.to_f) / l.plants_count_objetivo.to_f * 100).round(1)
      end
      {
        id:                       l.id,
        codigo:                   l.codigo,
        estado:                   l.estado,
        plants_count_objetivo:    l.plants_count_objetivo,
        plants_count_cosechadas:  l.plants_count_cosechadas,
        rendimiento_objetivo_g:   l.rendimiento_objetivo_g,
        rendimiento_real_g:       l.rendimiento_real_g,
        fecha_cosecha_estimada:   l.fecha_cosecha_estimada,
        desv_rendimiento_pct:     desv_rendimiento,
        desv_plantas_pct:         desv_plantas,
      }
    end

    lotes_con_obj = lotes.where.not(rendimiento_objetivo_g: nil)
    lotes_cerrados = lotes_con_obj.where.not(rendimiento_real_g: nil)

    promedio_desv = if lotes_cerrados.any?
      devs = lotes_cerrados.map do |l|
        (l.rendimiento_real_g.to_f - l.rendimiento_objetivo_g.to_f) / l.rendimiento_objetivo_g.to_f * 100
      end
      (devs.sum / devs.size).round(1)
    end

    datos = {
      total_lotes_con_objetivo: lotes_con_obj.count,
      total_lotes_cerrados:     lotes_cerrados.count,
      promedio_desviacion_pct:  promedio_desv,
      detalle:                  detalle,
    }

    responder_informe(
      titulo: 'Plan vs. real', nombre: 'informe_plan_vs_real', datos: datos,
      resena: 'Qué se propuso cada lote y qué consiguió: plantas y gramos objetivo contra los reales, con el desvío entre ambos.',
      kpis: [
        { label: 'Lotes con objetivo', valor: lotes_con_obj.count },
        { label: 'Ya cerrados',        valor: lotes_cerrados.count },
        { label: 'Desvío promedio',    valor: promedio_desv ? "#{promedio_desv}%" : '—',
          tono: promedio_desv && promedio_desv < 0 ? :crit : :ok },
      ],
      secciones: [{
        titulo: 'Detalle por lote',
        headers: ['Lote', 'Estado', 'Plantas obj.', 'Cosechadas', 'Gramos obj.', 'Reales', 'Desvío %'],
        rows: detalle.map { |l|
          [l[:codigo], l[:estado].to_s.tr('_', ' ').capitalize, l[:plants_count_objetivo],
           l[:plants_count_cosechadas], l[:rendimiento_objetivo_g], l[:rendimiento_real_g],
           l[:desv_rendimiento_pct]]
        },
        aligns: (2..6).to_h { |i| [i, :right] },
      }],
    )
  end

  # INASE — Registro de variedades de la organización + trazabilidad a producción.
  # Liga cada genética (con su dato INASE) con lo que realmente produjo: lotes,
  # plantas y gramos. Es el informe regulatorio de variedades cultivadas.
  # Qué se perdió, y por qué. Ningún informe lo decía: producción cuenta lo que salió bien y
  # trazabilidad cierra el balance de UN producto, pero la organización no tenía dónde ver cuánto se
  # cayó en total. Para quien audita es de lo primero que se pregunta; para el dueño es plata.
  def perdidas
    club = current_user.club
    desde, hasta = periodo_rango

    # 1. PLANTAS descartadas, con su motivo. Es la pérdida más cara: cada una es un ciclo que
    #    no llegó a cosecha.
    descartadas = Plant.joins(lote: :sala)
                       .where(salas: { sede_id: club.sede_ids }, state: 'descartada')
                       .where(updated_at: desde..hasta)
    por_motivo = descartadas.group(:motivo_descarte).count
                            .transform_keys { |m| (m || 'sin_motivo').to_s.tr('_', ' ').capitalize }

    # 2. MERMA de inventario: lo que salió del stock sin ser una dispensación. `merma` es la
    #    pérdida declarada; los ajustes negativos son correcciones de inventario que también
    #    son producto que ya no está.
    movs   = StockMovimiento.joins(stock: :sede)
                            .where(sedes: { club_id: club.id })
                            .where(created_at: desde..hasta)
    merma_g  = movs.where(tipo: 'merma').sum(:gramos).to_f.abs.round(1)
    ajuste_g = movs.where(tipo: 'ajuste').where('gramos < 0').sum(:gramos).to_f.abs.round(1)

    # 3. STOCK VENCIDO que sigue en góndola: todavía no es pérdida contable, pero lo va a ser.
    vencido = Stock.where(club_id: club.id).where('cantidad > 0')
                   .where.not(estado: 'agotado')
                   .where('fecha_vencimiento_est < ?', Time.zone.today)
    vencido_g = vencido.where(forma_producto: 'flor_seca').sum(:cantidad).to_f.round(1)

    datos = {
      plantas_descartadas: descartadas.count,
      plantas_por_motivo:  por_motivo,
      merma_g:             merma_g,
      ajustes_negativos_g: ajuste_g,
      total_gramos:        (merma_g + ajuste_g).round(1),
      stock_vencido_g:     vencido_g,
      stock_vencido_items: vencido.count,
    }

    secciones = [{
      titulo: 'Plantas descartadas, por motivo',
      headers: ['Motivo', 'Plantas'],
      rows: por_motivo.sort_by { |_, n| -n }.map { |motivo, n| [motivo, n] },
      formatos: [:texto, :numero],
      totales: [1],
      aligns: { 1 => :right },
      vacio: 'No se descartó ninguna planta en el período.',
    }, {
      titulo: 'Producto perdido',
      headers: ['Concepto', 'Gramos'],
      rows: [['Merma declarada', merma_g],
             ['Ajustes de inventario en menos', ajuste_g],
             ['Stock vencido todavía en góndola', vencido_g]],
      formatos: [:texto, :numero],
      aligns: { 1 => :right },
    }]

    responder_informe(
      titulo: 'Informe de pérdidas', nombre: 'informe_perdidas',
      resena: 'Qué se perdió la organización en el período y por qué: plantas que no llegaron a cosecha ' \
              'con su motivo, y producto que salió del inventario sin ser una dispensación ' \
              '(merma, ajustes en menos). El stock vencido todavía no es pérdida, pero lo va a ser.',
      datos: datos, periodo: etiqueta_periodo(desde, hasta),
      kpis: [
        { label: 'Plantas descartadas', valor: descartadas.count, tono: descartadas.count.positive? ? :warn : :ok },
        { label: 'Merma', valor: merma_g },
        { label: 'Ajustes en menos', valor: ajuste_g },
        { label: 'Vencido en góndola', valor: vencido_g, tono: vencido_g.positive? ? :crit : :ok },
      ],
      secciones: secciones,
    )
  end

  def inase
    club      = current_user.club
    geneticas = club.geneticas.order(:nombre)
    lotes     = club.lotes

    lotes_por_gen   = lotes.group(:genetica_id).count
    plantas_por_gen = lotes.group(:genetica_id).sum(:plants_count)
    gramos_por_gen  = lotes.where.not(rendimiento_real_g: nil).group(:genetica_id).sum(:rendimiento_real_g)

    filas = geneticas.includes(:declarada_como).map do |g|
      {
        id:                    g.id,
        # `nombre` es el que usa la organización puertas adentro; `nombre_declarado` es el que se
        # presenta ante el organismo. Un club cultiva "Northern Lights" y la declara contra
        # una variedad inscripta: el informe tiene que decir la inscripta.
        nombre:                g.nombre_declarado,
        nombre_propio:         g.nombre,
        declarada:             g.declarada_como.present?,
        acreditada:            g.acreditada_inase?,
        tipo:                  g.tipo,
        registrada_inase:      g.registrada_inase,
        numero_registro_inase: g.numero_inase_declarado,
        categoria_inase:       g.categoria_inase,
        fecha_registro_inase:  g.fecha_registro_inase,
        criador:               g.criador,
        thc:                   g.thc&.to_f,
        cbd:                   g.cbd&.to_f,
        lotes:                 lotes_por_gen[g.id] || 0,
        plantas:               plantas_por_gen[g.id].to_i,
        gramos_producidos:     (gramos_por_gen[g.id] || 0).to_f.round(1),
      }
    end

    registradas = filas.count { |f| f[:registrada_inase] }
    declaradas  = filas.count { |f| f[:declarada] }
    # Lo que le falta a la organización: lo que cultiva sin poder acreditarlo, ni por registro propio
    # ni por declaración. Es la única fila accionable del informe.
    pendientes  = filas.reject { |f| f[:acreditada] }

    # UNA FILA POR VARIEDAD ACREDITABLE, no por genética de la organización. Si veinte genéticas propias
    # se declaran contra TROPICANA WFC, listarlas por separado da veinte filas con el mismo
    # nombre —parece un error de datos— y encima al organismo le importa cuánto se cultivó de
    # esa variedad, no cómo la llama la organización puertas adentro. Los nombres propios van juntos en
    # "Se cultiva como", que es lo que hace auditable la traducción.
    agrupadas = filas.group_by { |g| g[:nombre] }.map do |nombre, gs|
      {
        nombre:   nombre,
        numero:   gs.filter_map { |g| g[:numero_registro_inase] }.first,
        propios:  gs.select { |g| g[:declarada] }.map { |g| g[:nombre_propio] },
        lotes:    gs.sum { |g| g[:lotes] },
        plantas:  gs.sum { |g| g[:plantas] },
        gramos:   gs.sum { |g| g[:gramos_producidos] }.round(1),
      }
    end.sort_by { |g| g[:nombre].to_s }

    datos = {
      total_geneticas:   filas.size,
      registradas_inase: registradas,
      declaradas:        declaradas,
      acreditadas:       registradas + declaradas,
      sin_registrar:     pendientes.size,
      gramos_totales:    filas.sum { |f| f[:gramos_producidos] }.round(1),
      lotes_totales:     filas.sum { |f| f[:lotes] },
      geneticas:         filas,
      agrupadas:         agrupadas,
      pendientes:        pendientes,
    }

    secciones = [{
      titulo: 'Variedades cultivadas',
      headers: ['Variedad', 'N° INASE', 'Se cultiva como', 'Lotes', 'Plantas', 'Gramos'],
      rows: agrupadas.map { |g|
        [g[:nombre], g[:numero].presence || 'Sin registrar',
         g[:propios].any? ? g[:propios].join(', ') : '—',
         g[:lotes], g[:plantas], g[:gramos]]
      },
      formatos: [:texto, :texto, :texto, :numero, :numero, :numero],
      totales: [3, 4, 5],
      aligns: { 3 => :right, 4 => :right, 5 => :right },
    }]

    if pendientes.any?
      secciones << {
        titulo: 'Sin acreditar — hay que declararlas contra una variedad inscripta',
        headers: ['Variedad', 'Lotes', 'Plantas'],
        rows: pendientes.map { |g| [g[:nombre_propio], g[:lotes], g[:plantas]] },
        formatos: [:texto, :numero, :numero],
        aligns: { 1 => :right, 2 => :right },
      }
    end

    responder_informe(
      titulo: 'Informe INASE — variedades', nombre: 'informe_inase', datos: datos,
      resena: 'Las variedades que la organización cultiva y con cuál acredita cada una ante el INASE. Una fila por variedad inscripta: si la organización la cultiva bajo otro nombre, ese nombre figura en «Se cultiva como». Al pie, lo que todavía no se puede acreditar.',
      kpis: [
        { label: 'Variedades',    valor: filas.size },
        { label: 'Inscriptas',    valor: registradas, tono: :ok },
        { label: 'Declaradas',    valor: declaradas,  tono: :ok },
        { label: 'Sin acreditar', valor: pendientes.size, tono: pendientes.any? ? :warn : :ok },
      ],
      secciones: secciones,
      nota: 'Las variedades que la organización no tiene inscriptas se presentan declaradas contra ' \
            'una variedad del registro INASE. La columna "Se cultiva como" deja ver el par.',
      # La pantalla se abre siempre —es la que lista los pendientes—; el archivo que se
      # presenta ante el organismo, no, mientras haya variedades sin acreditar.
      exige_declaracion_inase: true,
    )
  end

  private

  # Gramos producidos en el período, opcionalmente acotados a un estado de lote.
  #
  # La fuente es `lotes.rendimiento_real_g`: el peso que deja el cierre de manicura. La fecha
  # del lote es la de su paso a CURADO —el momento en que el producto existe— y si ese evento
  # falta se cae a `updated_at`. Antes esto salía de la tabla `pesadas`, que el flujo real no
  # llena, y el informe decía "0 gramos" con veinte lotes curados.
  def gramos_del_periodo(club, desde, hasta, estado: nil)
    scope = club.lotes.where.not(rendimiento_real_g: nil).where('rendimiento_real_g > 0')
    scope = scope.where(estado: estado) if estado

    # Fecha de curado por lote, en una sola consulta (evita N+1 sobre lote_eventos).
    curados = LoteEvento.where(lote_id: scope.select(:id), tipo: 'cambio_estado',
                               estado_nuevo: %w[curado finalizado])
                        .group(:lote_id).minimum(:registrado_en)

    scope.sum do |lote|
      fecha = curados[lote.id] || lote.updated_at
      fecha && fecha >= desde.to_time.beginning_of_day && fecha <= hasta.to_time.end_of_day ? lote.rendimiento_real_g.to_f : 0.0
    end.round(1)
  end

  # Datos del informe REPROCANN — compartidos por la respuesta JSON y el PDF
  def reprocann_data(club)
    # Este informe le habla AL ORGANISMO: declara la población registrada en REPROCANN. Por eso
    # sólo entran los pacientes que tienen registro —vigente, vencido o en trámite—. Que existan
    # pacientes sin REPROCANN es un pendiente interno de la organización, no algo que se presenta: eso se
    # gestiona desde Pacientes, donde además se puede hacer algo al respecto.
    #
    # Antes entraban todos, así que el total del informe no coincidía con nada y la tasa de
    # cumplimiento se calculaba contra una población que incluía a quienes ni siquiera iniciaron
    # el trámite.
    activos   = Paciente.for_club(club.id).where(es_paciente: true)
    # "Tiene registro" = tiene número, o su estado dice algo distinto de `sin_registro` (que es
    # el default de la columna: el paciente que nunca inició el trámite).
    pacientes = activos.where.not(reprocann_numero: [nil, ''])
                       .or(activos.where.not(reprocann_estado: [nil, '', 'sin_registro']))

    # Los que quedaron afuera se informan como un pendiente, con su número, no escondidos.
    sin_registro = activos.count - pacientes.count

    # Una sola clasificación para todo: los conteos son el histograma de la misma
    # categoría que se muestra en la lista, así el total cierra siempre.
    conteos = Hash.new(0)
    pacientes.pluck(:reprocann_estado, :reprocann_numero, :reprocann_vencimiento).each do |e, n, v|
      conteos[Paciente.reprocann_categoria(estado: e, numero: n, vencimiento: v)] += 1
    end

    lista = pacientes.limit(200).map do |p|
      {
        # Nombre completo y los últimos TRES del documento: este informe se presenta ante la
        # autoridad, que necesita saber de quién se habla. Las iniciales sirven para un
        # tablero interno, no para acreditar una nómina.
        nombre_completo:       p.nombre_completo,
        iniciales:             "#{p.nombre[0]}.#{p.apellido[0]}.",
        dni_ultimos_3:         p.dni_normalizado.to_s.last(3),
        dni_ultimos_4:         p.dni_normalizado.to_s.last(4),
        reprocann_estado:      p.reprocann_categoria,
        reprocann_vencimiento: p.reprocann_vencimiento,
      }
    end

    {
      total_pacientes:        conteos.values.sum,
      con_reprocann_vigente:  conteos['vigente'],
      vencen_30d:             conteos['por_vencer'],
      vencidos:               conteos['vencido'],
      pendientes:             conteos['pendiente'],
      sin_reprocann:          conteos['sin_reprocann'],
      lista_anonimizada:      lista,
      # Sin corte por sede: un PACIENTE NO TIENE SEDE — es de la organización. Lo que había agrupaba por
      # la sede de su última dispensación, una dimensión inventada que además dejaba a los que
      # nunca dispensaron en una fila fantasma. La actividad por sede es otra pregunta y vive
      # en el informe de dispensaciones.
      pacientes_sin_registro: sin_registro,
      dispensaciones:         reprocann_dispensaciones(club, pacientes),
      # El informe de Cumplimiento era esto mismo con otro título: sus cuatro KPIs salían de
      # los conteos que ya se calculan acá arriba. Vive adentro de REPROCANN, que es de lo que
      # habla.
      cumplimiento:           cumplimiento_data(club, conteos),
    }
  end

  # Tasa de cumplimiento y alertas de la población de pacientes. Recibe los conteos ya hechos
  # por `reprocann_data` para no recorrer dos veces lo mismo.
  def cumplimiento_data(club, conteos)
    total     = conteos.values.sum
    vigente   = conteos['vigente']
    por_vencer = conteos['por_vencer']
    vencidos  = conteos['vencido']
    sin_seg   = Paciente.for_club(club.id).where(es_paciente: true, con_seguimiento_medico: false).count

    # Quien vence en 20 días HOY está en regla: cuenta como cumplimiento, aunque tenga alerta.
    en_regla = vigente + por_vencer
    tasa = total.positive? ? ((en_regla.to_f / total) * 100).round(1) : 0

    alertas = []
    alertas << { severidad: 'error',   detalle: "#{vencidos} pacientes con REPROCANN vencido" } if vencidos > 0
    alertas << { severidad: 'warning', detalle: "#{por_vencer} pacientes vencen en ≤30 días" }  if por_vencer > 0
    alertas << { severidad: 'warning', detalle: "#{sin_seg} pacientes sin seguimiento médico" } if sin_seg > 0

    { tasa: tasa, en_regla: en_regla, sin_seguimiento_medico: sin_seg, alertas: alertas }
  end

  # Actividad de dispensación de la población informada. Es lo que le da sentido al informe:
  # no alcanza con decir cuántos pacientes hay en regla, importa a quién se le entregó y si
  # tenía el certificado al día. Nada de cultivo: eso vive en los informes de Producción.
  def reprocann_dispensaciones(club, pacientes)
    ids = pacientes.pluck(:id)
    return { total: 0, gramos: 0.0, pacientes_atendidos: 0, sin_reprocann_vigente: 0 } if ids.empty?

    disps = Dispensacion.no_canceladas
                        .where(paciente_id: ids)
                        .joins(stock: :sede)
                        .where(sedes: { club_id: club.id })

    # Los que recibieron algo sin tener el certificado en regla: el dato que un auditor busca.
    categorias = pacientes.pluck(:id, :reprocann_estado, :reprocann_numero, :reprocann_vencimiento)
                          .to_h { |pid, e, n, v|
                            [pid, Paciente.reprocann_categoria(estado: e, numero: n, vencimiento: v)]
                          }
    atendidos = disps.distinct.pluck(:paciente_id)
    en_falta  = atendidos.count { |pid| %w[vencido sin_reprocann].include?(categorias[pid]) }

    {
      total:                 disps.count,
      gramos:                disps.sum(:cantidad).to_f.round(1),
      pacientes_atendidos:   atendidos.size,
      sin_reprocann_vigente: en_falta,
    }
  end

  # Pacientes por sede de atención. El paciente NO tiene sede propia: se atiende donde
  # dispensa, así que la sede sale de sus dispensaciones (la más reciente manda, porque
  # alguien que se mudó de sede cuenta en la que se atiende hoy).
  #
  # Es lo único no-clínico que el informe agrega más allá de los pacientes: nada de cultivo,
  # que vive en los informes de Producción y Sedes.
  # Se perdió al sacar el corte por sede (estaba en ese rango de líneas) y la exportación a
  # Excel del informe REPROCANN se caía con NameError.
  ESTADO_REPROCANN_LABEL = {
    'vigente'                 => 'Vigente',
    'vigente_sin_vencimiento' => 'Vigente sin vencimiento',
    'por_vencer'              => 'Por vencer (hasta 30 días)',
    'vencido'                 => 'Vencido',
    'pendiente'               => 'Pendiente de aprobación',
    'sin_reprocann'           => 'Sin REPROCANN',
  }.freeze

  def reprocann_xlsx(club, data)
    rows = (data[:lista_anonimizada] || []).map do |p|
      venc = p[:reprocann_vencimiento].present? ? Date.parse(p[:reprocann_vencimiento].to_s).strftime('%d/%m/%Y') : '—'
      [
        p[:nombre_completo].presence || p[:iniciales].to_s,
        p[:dni_ultimos_3].present? ? "***#{p[:dni_ultimos_3]}" : '—',
        ESTADO_REPROCANN_LABEL[p[:reprocann_estado].to_s] || p[:reprocann_estado].to_s,
        venc,
      ]
    end
    XlsxExport.new(
      club:    club,
      titulo:  'Informe REPROCANN',
      headers: ['Paciente', 'DNI (últ. 3)', 'Estado', 'Vencimiento'],
      rows:    rows,
      anchos:  [14, 16, 28, 16],
    ).render
  end

  # Rótulo legible del período, para el encabezado del PDF y del Excel.
  def etiqueta_periodo(desde, hasta)
    return nil if desde.blank? || hasta.blank?
    "#{desde.strftime('%d/%m/%Y')} — #{hasta.strftime('%d/%m/%Y')}"
  end

  def fmt_fecha(f)
    return '—' if f.blank?
    (f.is_a?(String) ? Date.parse(f) : f).strftime('%d/%m/%Y')
  rescue ArgumentError
    f.to_s
  end

  def periodo_rango
    periodo = params[:periodo].presence_in(PERIODO_RANGOS.keys) || 'mes_actual'
    PERIODO_RANGOS[periodo].call
  end

  def require_auditor_o_admin!
    unless current_user&.admin? || current_user&.auditor?
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end
end
