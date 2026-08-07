class InformesController < ApplicationController
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

  def produccion
    club  = current_user.club
    desde, hasta = periodo_rango

    total_lotes   = club.lotes.count
    lotes_activos = club.lotes.where.not(estado: %w[finalizado]).count
    lotes_cosechados = club.lotes.where(estado: 'finalizado')
                           .where(updated_at: desde..hasta).count

    gramos_producidos = Pesada.joins(:lote)
                              .where(lotes: { club_id: club.id }, fase_destino: 'finalizado')
                              .where(registrado_at: desde..hasta)
                              .sum('COALESCE(peso_curado_g, 0)').to_f

    plantas_totales = Plant.joins(lote: :sala).where(salas: { sede_id: club.sede_ids })
                           .where.not(state: %w[cosechado finalizado]).count

    # Agregados por estado en 2 group-queries (evita N+1) + gramos por estado no vacío.
    lotes_por_estado   = club.lotes.group(:estado).count
    plantas_por_estado = club.lotes.group(:estado).sum(:plants_count)
    por_estado = Lote::ESTADOS.filter_map do |e|
      next if (lotes_e = lotes_por_estado[e].to_i).zero?
      # MISMO período que `gramos_producidos`: el desglose no lo filtraba, así que sus gramos
      # sumaban más que el total del encabezado y el informe se contradecía a sí mismo.
      gramos_e = Pesada.joins(:lote)
                       .where(lotes: { club_id: club.id, estado: e }, fase_destino: 'finalizado')
                       .where(registrado_at: desde..hasta)
                       .sum('COALESCE(peso_curado_g, 0)').to_f
      { estado: e, lotes: lotes_e, plantas: plantas_por_estado[e].to_i, gramos: gramos_e }
    end

    render json: {
      total_lotes:      total_lotes,
      lotes_activos:    lotes_activos,
      lotes_cosechados: lotes_cosechados,
      gramos_producidos: gramos_producidos,
      plantas_totales:  plantas_totales,
      por_estado:       por_estado,
    }
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

    resumen = disps.includes(:paciente).group_by(&:paciente_id).map do |_, ds|
      p = ds.first.paciente
      {
        iniciales:    "#{p.nombre[0]}.#{p.apellido[0]}.",
        cantidad:     ds.size,
        total_gramos: ds.sum { |d| d.cantidad.to_f }.round(2),
        ultima_fecha: ds.max_by(&:fecha_dispensacion)&.fecha_dispensacion,
      }
    end.first(100)

    render json: {
      total_dispensaciones:    total,
      gramos_dispensados:      gramos,
      pacientes_atendidos:     pax,
      promedio_por_dispensacion: promedio,
      resumen_anonimizado:     resumen,
    }
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

    render json: {
      total_sedes:    sedes.count,
      sedes_activas:  sedes_activas,
      salas_totales:  salas_totales,
      plantas_totales: plantas_totales,
      por_sede:       por_sede,
    }
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

    render json: {
      pacientes_con_reprocann_vigente: con_vigente,
      reprocann_vencen_30d:            vencen_30d,
      reprocann_vencidos:              vencidos,
      dispensaciones_sin_reprocann:    disp_sin_reprocann,
      tasa_cumplimiento:               tasa,
      alertas:                         alertas,
    }
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

    render json: {
      total_lotes_con_objetivo: lotes_con_obj.count,
      total_lotes_cerrados:     lotes_cerrados.count,
      promedio_desviacion_pct:  promedio_desv,
      detalle:                  detalle,
    }
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

    filas = geneticas.map do |g|
      {
        id:                    g.id,
        nombre:                g.nombre,
        tipo:                  g.tipo,
        registrada_inase:      g.registrada_inase,
        numero_registro_inase: g.numero_registro_inase,
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
    render json: {
      total_geneticas:   filas.size,
      registradas_inase: registradas,
      sin_registrar:     filas.size - registradas,
      gramos_totales:    filas.sum { |f| f[:gramos_producidos] }.round(1),
      lotes_totales:     filas.sum { |f| f[:lotes] },
      geneticas:         filas,
    }
  end

  private

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
        iniciales:             "#{p.nombre[0]}.#{p.apellido[0]}.",
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
        p[:iniciales].to_s,
        p[:dni_ultimos_4].present? ? "**** #{p[:dni_ultimos_4]}" : '—',
        ESTADO_REPROCANN_LABEL[p[:reprocann_estado].to_s] || p[:reprocann_estado].to_s,
        venc,
      ]
    end
    XlsxExport.new(
      club:    club,
      titulo:  'Informe REPROCANN',
      headers: ['Iniciales', 'DNI (últ. 4)', 'Estado', 'Vencimiento'],
      rows:    rows,
      anchos:  [14, 16, 28, 16],
    ).render
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
