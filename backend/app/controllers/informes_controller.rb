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
  def responder_informe(titulo:, datos:, kpis:, secciones:, nombre:, periodo: nil, nota: nil,
                        exige_declaracion_inase: false)
    respond_to do |format|
      format.json { render json: datos }
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
    # está vacía —el club pesa por PesajeManicura, no por Pesada— así que el informe mostraba
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

      { estado: e, lotes: lotes_e, plantas: plantas_por_estado[e].to_i,
        gramos: gramos_del_periodo(club, desde, hasta, estado: e) }
    end

    datos = {
      total_lotes:      total_lotes,
      lotes_activos:    lotes_activos,
      lotes_cosechados: lotes_cosechados,
      gramos_producidos: gramos_producidos,
      plantas_totales:  plantas_totales,
      por_estado:       por_estado,
    }

    responder_informe(
      titulo: 'Informe de producción', nombre: 'informe_produccion',
      datos: datos, periodo: etiqueta_periodo(desde, hasta),
      kpis: [
        { label: 'Lotes totales',   valor: total_lotes },
        { label: 'Lotes activos',   valor: lotes_activos, tono: :ok },
        { label: 'Cosechados',      valor: lotes_cosechados },
        { label: 'Gramos del período', valor: gramos_producidos.round(1) },
        { label: 'Plantas en pie',  valor: plantas_totales },
      ],
      secciones: [{
        titulo: 'Por estado del lote',
        headers: ['Estado', 'Lotes', 'Plantas', 'Gramos'],
        rows: por_estado.map { |e| [e[:estado].to_s.tr('_', ' ').capitalize, e[:lotes], e[:plantas], e[:gramos]] },
        formatos: [:texto, :numero, :numero, :numero],
        totales: [1, 2, 3],
        aligns: { 1 => :right, 2 => :right, 3 => :right },
      }],
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
    # pero quien abre este informe (admin o auditor del club) ya puede ver la ficha entera del
    # paciente: la inicial no protegía nada y volvía el informe ilegible — con dos "G.L." no
    # se sabe de quién se habla ni se puede cruzar con nada.
    resumen = disps.includes(:paciente).group_by(&:paciente_id).map do |_, ds|
      p = ds.first.paciente
      {
        paciente:     p.nombre_completo,
        iniciales:    "#{p.nombre[0]}.#{p.apellido[0]}.",   # se mantiene por compatibilidad
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
      datos: datos, periodo: etiqueta_periodo(desde, hasta),
      kpis: [
        { label: 'Entregas',           valor: total },
        { label: 'Gramos dispensados', valor: gramos.round(1), tono: :ok },
        { label: 'Pacientes',          valor: pax },
        { label: 'Promedio por entrega', valor: promedio },
      ],
      secciones: [{
        titulo: 'Detalle por paciente',
        headers: ['Paciente', 'Entregas', 'Gramos', 'Última entrega'],
        rows: resumen.map { |r| [r[:paciente], r[:cantidad], r[:total_gramos], fmt_fecha(r[:ultima_fecha])] },
        formatos: [:texto, :numero, :numero, :texto],
        totales: [1, 2],
        aligns: { 1 => :right, 2 => :right },
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

  # INASE — Registro de variedades del club + trazabilidad a producción.
  # Liga cada genética (con su dato INASE) con lo que realmente produjo: lotes,
  # plantas y gramos. Es el informe regulatorio de variedades cultivadas.
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
        # `nombre` es el que usa el club puertas adentro; `nombre_declarado` es el que se
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
    # Lo que le falta al club: lo que cultiva sin poder acreditarlo, ni por registro propio
    # ni por declaración. Es la única fila accionable del informe.
    pendientes  = filas.reject { |f| f[:acreditada] }

    datos = {
      total_geneticas:   filas.size,
      registradas_inase: registradas,
      declaradas:        declaradas,
      acreditadas:       registradas + declaradas,
      sin_registrar:     pendientes.size,
      gramos_totales:    filas.sum { |f| f[:gramos_producidos] }.round(1),
      lotes_totales:     filas.sum { |f| f[:lotes] },
      geneticas:         filas,
      pendientes:        pendientes,
    }

    secciones = [{
      titulo: 'Variedades cultivadas',
      headers: ['Variedad', 'N° INASE', 'Se cultiva como', 'Lotes', 'Plantas', 'Gramos'],
      rows: filas.map { |g|
        [g[:nombre], g[:numero_registro_inase].presence || 'Sin registrar',
         # La columna que hace auditable la traducción: contra qué nombre real corresponde
         # cada variedad declarada. En blanco cuando el nombre no cambió.
         g[:declarada] ? g[:nombre_propio] : '—',
         g[:lotes], g[:plantas], g[:gramos_producidos]]
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
      kpis: [
        { label: 'Variedades',    valor: filas.size },
        { label: 'Inscriptas',    valor: registradas, tono: :ok },
        { label: 'Declaradas',    valor: declaradas,  tono: :ok },
        { label: 'Sin acreditar', valor: pendientes.size, tono: pendientes.any? ? :warn : :ok },
      ],
      secciones: secciones,
      nota: 'Las variedades que el club no tiene inscriptas se presentan declaradas contra ' \
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
    # El informe es sobre la población ACTIVA del club: alguien dado de baja no se le
    # informa a nadie ni cuenta para la tasa de cumplimiento.
    pacientes = Paciente.for_club(club.id).where(es_paciente: true)

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
      por_sede:               reprocann_por_sede(club, pacientes),
      dispensaciones:         reprocann_dispensaciones(club, pacientes),
    }
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
  def reprocann_por_sede(club, pacientes)
    ids = pacientes.pluck(:id)
    return [] if ids.empty?

    # Última dispensación de cada paciente, y de qué sede salió.
    ultima_sede = Dispensacion.no_canceladas
                              .where(paciente_id: ids)
                              .joins(stock: :sede)
                              .where(sedes: { club_id: club.id })
                              .order(:paciente_id, fecha_dispensacion: :desc, id: :desc)
                              .pluck(:paciente_id, 'sedes.id', 'sedes.nombre')
                              .each_with_object({}) { |(pid, sid, snom), h| h[pid] ||= [sid, snom] }

    datos = pacientes.pluck(:id, :reprocann_estado, :reprocann_numero, :reprocann_vencimiento)
    agrupado = Hash.new { |h, k| h[k] = Hash.new(0) }

    datos.each do |pid, estado, numero, venc|
      _sid, nombre = ultima_sede[pid]
      cat = Paciente.reprocann_categoria(estado: estado, numero: numero, vencimiento: venc)
      agrupado[nombre || 'Sin dispensaciones'][cat] += 1
    end

    agrupado.map do |sede, cats|
      {
        sede:      sede,
        total:     cats.values.sum,
        vigentes:  cats['vigente'],
        por_vencer: cats['por_vencer'],
        vencidos:  cats['vencido'],
        pendientes: cats['pendiente'],
        sin_reprocann: cats['sin_reprocann'],
      }
    end.sort_by { |r| -r[:total] }
  end

  ESTADO_REPROCANN_LABEL = {
    'vigente'                 => 'Vigente',
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
