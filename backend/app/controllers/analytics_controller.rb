class AnalyticsController < ApplicationController
  before_action :authenticate_user!

  # GET /api/analytics/rendimiento_genetica
  # Para: admin, supervisor, super_admin
  def rendimiento_genetica
    unless %w[admin supervisor super_admin].include?(current_user.role)
      return render json: { error: 'No autorizado' }, status: :forbidden
    end

    club = current_user.club
    año  = params[:año].presence
    cache_key = "analytics/rendimiento_genetica/#{club.id}/#{año || 'all'}"
    Rails.cache.delete(cache_key) if params[:bust]
    data = Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
      calcular_rendimiento_genetica(club, año: año)
    end
    render json: data
  end

  def calcular_rendimiento_genetica(club, año: nil)
    lotes = club.lotes.where.not(estado: 'germinacion').includes(:genetica)
    lotes = lotes.where('EXTRACT(YEAR FROM COALESCE(start_date, created_at)) = ?', año) if año

    # Rendimiento por genética (solo lotes con datos reales)
    por_genetica = lotes.group_by { |l| l.genetica_id }.filter_map do |gid, ls|
      genetica = ls.first&.genetica
      next unless genetica

      con_rendimiento = ls.select { |l| l.rendimiento_real_g.present? }
      rendimiento_avg = con_rendimiento.any? ? (con_rendimiento.sum { |l| l.rendimiento_real_g.to_f } / con_rendimiento.size).round(1) : nil

      objetivo_avg = begin
        obj = ls.select { |l| l.rendimiento_objetivo_g.present? }
        obj.any? ? (obj.sum { |l| l.rendimiento_objetivo_g.to_f } / obj.size).round(1) : nil
      end

      merma_avg = begin
        con_merma = ls.select { |l| l.plants_count.present? && l.plants_count_cosechadas.present? && l.plants_count > 0 }
        if con_merma.any?
          mermas = con_merma.map { |l| ((l.plants_count - l.plants_count_cosechadas).to_f / l.plants_count * 100).round(1) }
          (mermas.sum / mermas.size).round(1)
        end
      end

      con_ambos     = ls.select { |l| l.rendimiento_real_g.present? && l.plants_count.present? && l.plants_count > 0 }
      g_por_planta  = con_ambos.any? ? (con_ambos.sum { |l| l.rendimiento_real_g.to_f / l.plants_count } / con_ambos.size).round(1) : nil

      {
        genetica_id:          gid,
        nombre:               genetica.nombre,
        lotes_total:          ls.size,
        lotes_finalizados:    ls.count { |l| l.rendimiento_real_g.present? },
        rendimiento_promedio: rendimiento_avg,
        objetivo_promedio:    objetivo_avg,
        desviacion_promedio:  rendimiento_avg && objetivo_avg ? ((rendimiento_avg - objetivo_avg) / objetivo_avg * 100).round(1) : nil,
        merma_promedio_pct:   merma_avg,
        g_por_planta:         g_por_planta,
        lotes_activos:        ls.count { |l| !%w[germinacion finalizado].include?(l.estado) },
      }
    end.sort_by { |r| [-(r[:rendimiento_promedio] || 0)] }

    # Top lotes recientes
    lotes_recientes = club.lotes
                          .includes(:genetica)
                          .where.not(estado: %w[germinacion])
                          .order(created_at: :desc)
                          .limit(20)
                          .map do |l|
      {
        id:                  l.id,
        codigo:              l.codigo,
        estado:              l.estado,
        genetica:            l.genetica&.nombre,
        plants_count:        l.plants_count,
        rendimiento_real_g:  l.rendimiento_real_g&.to_f,
        rendimiento_obj_g:   l.rendimiento_objetivo_g&.to_f,
        g_por_planta:        l.rendimiento_real_g && l.plants_count.to_i > 0 ? (l.rendimiento_real_g.to_f / l.plants_count).round(1) : nil,
        desv_pct:            l.rendimiento_real_g && l.rendimiento_objetivo_g ? ((l.rendimiento_real_g.to_f - l.rendimiento_objetivo_g.to_f) / l.rendimiento_objetivo_g.to_f * 100).round(1) : nil,
        created_at:          l.created_at,
      }
    end

    # Resumen global
    lotes_finalizados = lotes.select { |l| l.rendimiento_real_g.present? }
    rendimiento_global = lotes_finalizados.any? ? (lotes_finalizados.sum { |l| l.rendimiento_real_g.to_f } / lotes_finalizados.size).round(1) : nil

    {
      resumen: {
        lotes_totales:        lotes.count,
        lotes_finalizados:    lotes_finalizados.size,
        geneticas_activas:    por_genetica.count { |g| g[:lotes_activos] > 0 },
        rendimiento_global_g: rendimiento_global,
      },
      por_genetica:    por_genetica,
      lotes_recientes: lotes_recientes,
    }
  end

  # GET /api/analytics/dispensador
  # Para: dispensador, admin
  def dispensador
    unless %w[admin dispensador super_admin].include?(current_user.role)
      return render json: { error: 'No autorizado' }, status: :forbidden
    end

    club = current_user.club
    data = Rails.cache.fetch("analytics/dispensador/#{club.id}/#{Date.today}", expires_in: 10.minutes) do
      calcular_dispensador(club)
    end
    render json: data
  end

  def calcular_dispensador(club)
    hoy    = Date.today
    inicio_semana = hoy.beginning_of_week
    inicio_mes    = hoy.beginning_of_month

    # Scope dispensaciones del club
    base_disps = Dispensacion.joins(stock: :sede)
                             .where(sedes: { club_id: club.id })

    disps_hoy     = base_disps.where(fecha_dispensacion: hoy..hoy)
    disps_semana  = base_disps.where(fecha_dispensacion: inicio_semana..hoy)
    disps_mes     = base_disps.where(fecha_dispensacion: inicio_mes..hoy)

    # Stock por producto
    stocks = Stock.joins(:sede)
                  .where(sedes: { club_id: club.id })
                  .disponibles
                  .asignados
                  .includes(:lote)

    stock_bajo_umbral = 50.0
    stocks_data = stocks.group_by(&:forma_producto).map do |forma, ss|
      total = ss.sum { |s| s.cantidad.to_f }
      { forma: forma, cantidad_g: total.round(2), alerta: total < stock_bajo_umbral }
    end.sort_by { |s| s[:cantidad_g] }

    # Pacientes REPROCANN por vencer
    pacientes = Paciente.for_club(club.id)
    reprocann_por_vencer = pacientes.reprocann_por_vencer.count
    reprocann_vencidos   = pacientes.where('reprocann_vencimiento < ?', hoy).count

    # Top pacientes del mes
    top_pacientes = base_disps
      .where(fecha_dispensacion: inicio_mes..hoy)
      .includes(:paciente)
      .group(:paciente_id)
      .select('paciente_id, SUM(dispensaciones.cantidad) AS total_g, COUNT(*) AS dispens_count')
      .order('total_g DESC')
      .limit(10)
      .map do |r|
        p = r.paciente
        {
          iniciales:      "#{p&.nombre&.[](0)}.#{p&.apellido&.[](0)}.",
          dni_last4:      p&.dni_normalizado.to_s.last(4),
          total_g:        r.total_g.to_f.round(2),
          dispens_count:  r.dispens_count,
        }
      end

    por_dia = (6.days.ago.to_date..Date.today).map do |date|
      { fecha: date.strftime('%d/%m'), count: base_disps.where(fecha_dispensacion: date).count }
    end

    {
      resumen: {
        dispensaciones_hoy:    disps_hoy.count,
        gramos_hoy:            disps_hoy.sum(:cantidad).to_f.round(2),
        dispensaciones_semana: disps_semana.count,
        gramos_semana:         disps_semana.sum(:cantidad).to_f.round(2),
        dispensaciones_mes:    disps_mes.count,
        gramos_mes:            disps_mes.sum(:cantidad).to_f.round(2),
      },
      reprocann: {
        por_vencer: reprocann_por_vencer,
        vencidos:   reprocann_vencidos,
      },
      stocks:        stocks_data,
      top_pacientes: top_pacientes,
      por_dia:       por_dia,
    }
  end

  # GET /api/analytics/correlacion_ambiental
  # Para: admin, supervisor, super_admin
  def correlacion_ambiental
    unless %w[admin supervisor super_admin].include?(current_user.role)
      return render json: { error: 'No autorizado' }, status: :forbidden
    end

    club = current_user.club
    año  = params[:año].presence
    cache_key = "analytics/correlacion_ambiental/#{club.id}/#{año || 'all'}"
    Rails.cache.delete(cache_key) if params[:bust]
    data = Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
      calcular_correlacion_ambiental(club, año: año)
    end
    render json: data
  end

  # GET /api/analytics/produccion
  # Para: admin, supervisor, super_admin
  def produccion
    unless %w[admin supervisor super_admin].include?(current_user.role)
      return render json: { error: 'No autorizado' }, status: :forbidden
    end

    club = current_user.club
    año  = params[:año].presence
    cache_key = "analytics/produccion/#{club.id}/#{año || 'all'}"
    Rails.cache.delete(cache_key) if params[:bust]
    data = Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
      calcular_produccion(club, año: año)
    end
    render json: data
  end

  private

  TIPOS_CORRELACION = %w[temperatura humedad vpd ph co2 ec ppfd].freeze

  VPD_BUCKETS = [
    [nil,  0.8, 'Bajo (<0.8 kPa)'],
    [0.8,  1.2, 'Óptimo bajo (0.8–1.2 kPa)'],
    [1.2,  1.6, 'Óptimo (1.2–1.6 kPa)'],
    [1.6,  2.0, 'Alto (1.6–2.0 kPa)'],
    [2.0,  nil, 'Muy alto (>2.0 kPa)'],
  ].freeze

  TEMP_BUCKETS = [
    [nil,  20.0, 'Frío (<20°C)'],
    [20.0, 23.0, 'Fresco (20–23°C)'],
    [23.0, 26.0, 'Óptimo (23–26°C)'],
    [26.0, 29.0, 'Cálido (26–29°C)'],
    [29.0, nil,  'Caliente (>29°C)'],
  ].freeze

  PH_BUCKETS = [
    [nil, 5.8, 'Ácido (<5.8)'],
    [5.8, 6.2, 'Óptimo (5.8–6.2)'],
    [6.2, 6.8, 'Normal (6.2–6.8)'],
    [6.8, nil, 'Alcalino (>6.8)'],
  ].freeze

  def calcular_correlacion_ambiental(club, año: nil)
    lotes = club.lotes
                .where(estado: 'finalizado')
                .where.not(rendimiento_real_g: nil)
                .includes(:genetica)
    lotes = lotes.where('EXTRACT(YEAR FROM COALESCE(start_date, created_at)) = ?', año) if año

    # Precarga lecturas en memoria agrupadas por lote para evitar N+1
    lote_ids = lotes.map(&:id)
    lecturas_por_lote = LecturaAmbiental
      .where(lote_id: lote_ids)
      .group_by(&:lote_id)

    lotes_data = lotes.filter_map do |l|
      lecturas = lecturas_por_lote[l.id] || []
      next if lecturas.empty?

      promedios = TIPOS_CORRELACION.each_with_object({}) do |tipo, h|
        vals = lecturas.select { |r| r.tipo == tipo }.map { |r| r.valor.to_f }
        h[tipo.to_sym] = vals.any? ? (vals.sum / vals.size).round(2) : nil
      end
      next if promedios.values.all?(&:nil?)

      rend = l.rendimiento_real_g.to_f
      obj  = l.rendimiento_objetivo_g&.to_f

      {
        lote_id:       l.id,
        codigo:        l.codigo,
        genetica:      l.genetica&.nombre,
        rendimiento_g: rend,
        objetivo_g:    obj,
        desv_pct:      (obj && obj > 0) ? ((rend - obj) / obj * 100).round(1) : nil,
        n_registros:   lecturas.size,
        **promedios,
      }
    end.sort_by { |l| -(l[:rendimiento_g] || 0) }

    regresiones = TIPOS_CORRELACION.each_with_object({}) do |tipo, h|
      pairs = lotes_data.filter_map { |l| v = l[tipo.to_sym]; [v, l[:rendimiento_g]] if v }
      h[tipo.to_sym] = regresion_lineal(pairs.map(&:first), pairs.map(&:last))
    end

    {
      lotes:            lotes_data,
      vpd_buckets:      agrupar_buckets(lotes_data, :vpd,         VPD_BUCKETS),
      temp_buckets:     agrupar_buckets(lotes_data, :temperatura,  TEMP_BUCKETS),
      ph_buckets:       agrupar_buckets(lotes_data, :ph,           PH_BUCKETS),
      regresiones:,
      total_con_datos:  lotes_data.size,
      total_finalizados: lotes.count,
    }
  end

  def agrupar_buckets(lotes_data, campo, rangos)
    rangos.filter_map do |min, max, label|
      subset = lotes_data.select do |l|
        v = l[campo]
        next false if v.nil?
        (min.nil? || v >= min) && (max.nil? || v < max)
      end
      next if subset.empty?

      con_desv = subset.select { |l| l[:desv_pct] }
      {
        label:    label,
        count:    subset.size,
        rend_avg: (subset.sum { |l| l[:rendimiento_g] } / subset.size).round(1),
        desv_avg: con_desv.any? ? (con_desv.sum { |l| l[:desv_pct] } / con_desv.size).round(1) : nil,
      }
    end
  end

  def calcular_produccion(club, año: nil)
    lotes = club.lotes.includes(:genetica, :plants).where.not(estado: 'germinacion')
    lotes = lotes.where('EXTRACT(YEAR FROM COALESCE(start_date, created_at)) = ?', año) if año

    # ── 1. PÉRDIDAS por cepa ───────────────────────────────────────
    perdidas_por_genetica = lotes.group_by(&:genetica_id).filter_map do |gid, ls|
      g = ls.first&.genetica
      next unless g

      con_datos = ls.select { |l| l.plants_count.present? && l.plants_count > 0 }
      next if con_datos.empty?

      mermas = con_datos.map do |l|
        cosechadas = l.plants_count_cosechadas || l.plants.where(state: 'cosechado').count
        descartadas = l.plants.where(state: 'descartada').count
        total = l.plants_count
        {
          lote_id:         l.id,
          lote_codigo:     l.codigo,
          total:           total,
          cosechadas:      cosechadas,
          descartadas:     descartadas,
          merma_pct:       total > 0 ? ((total - cosechadas).to_f / total * 100).round(1) : nil,
          descarte_pct:    total > 0 ? (descartadas.to_f / total * 100).round(1) : nil,
        }
      end

      merma_avg   = mermas.filter_map { |m| m[:merma_pct] }
      descarte_avg = mermas.filter_map { |m| m[:descarte_pct] }

      {
        genetica_id:      gid,
        nombre:           g.nombre,
        lotes_count:      ls.size,
        merma_promedio:   merma_avg.any? ? (merma_avg.sum / merma_avg.size).round(1) : nil,
        descarte_promedio: descarte_avg.any? ? (descarte_avg.sum / descarte_avg.size).round(1) : nil,
        por_lote:         mermas.sort_by { |m| m[:lote_codigo] },
      }
    end.sort_by { |r| [-(r[:merma_promedio] || 0)] }

    # ── 2. CICLOS — tiempo en cada fase por cepa ────────────────────
    # Usa lote_eventos para calcular días reales entre transiciones
    eventos_por_lote = LoteEvento
      .where(lote_id: lotes.map(&:id), tipo: 'cambio_estado')
      .order(:registrado_en)
      .group_by(&:lote_id)

    ciclos_por_lote = lotes.filter_map do |l|
      evs = eventos_por_lote[l.id] || []
      next if evs.empty? && l.start_date.nil?

      # start_date es siempre el ancla del período vegetativo total (incluye propagación)
      fase_inicio = {}
      fase_inicio['vegetativo'] = l.start_date&.to_time

      evs.each do |ev|
        next unless ev.estado_nuevo.present?
        # No sobreescribir 'vegetativo' — start_date es el inicio real del período completo.
        # Los eventos esqueje/semilla se guardan como sub-fases de propagación.
        next if ev.estado_nuevo == 'vegetativo'
        fase_inicio[ev.estado_nuevo] = ev.registrado_en
      end

      fases = %w[vegetativo floracion cosecha secado curado]
      dias = {}
      fases.each_with_index do |fase, idx|
        inicio = fase_inicio[fase]
        siguiente = fases[idx + 1]
        fin = siguiente ? fase_inicio[siguiente] : nil
        fin ||= Time.current if l.estado == fase
        dias[fase] = inicio && fin ? ((fin - inicio) / 86400.0).round(1) : nil
      end

      next if dias.values.all?(&:nil?)

      # ── Sub-fases de propagación (detalle dentro del período vegetativo) ──
      # propagacion = días desde start_date hasta transición a vegetativo pleno
      # vegetativo_puro = días desde vegetativo pleno hasta floracion
      ev_vegetativo = evs.find { |e| e.estado_nuevo == 'vegetativo' }
      if ev_vegetativo && l.start_date
        propagacion_dias = ((ev_vegetativo.registrado_en - l.start_date.to_time) / 86400.0).round(1)
        veg_puro_fin     = fase_inicio['floracion']
        veg_puro_fin   ||= Time.current if l.estado == 'vegetativo'
        veg_puro_dias    = veg_puro_fin ? ((veg_puro_fin - ev_vegetativo.registrado_en) / 86400.0).round(1) : nil
      else
        propagacion_dias = nil
        veg_puro_dias    = nil
      end

      {
        lote_id:        l.id,
        lote_codigo:    l.codigo,
        genetica_id:    l.genetica_id,
        propagacion:    propagacion_dias,
        vegetativo_puro: veg_puro_dias,
        **dias,
      }
    end

    ciclos_por_genetica = ciclos_por_lote.group_by { |c| c[:genetica_id] }.filter_map do |gid, cs|
      g = lotes.find { |l| l.genetica_id == gid }&.genetica
      next unless g

      fases = %w[vegetativo floracion cosecha secado curado]
      promedios = fases.map do |fase|
        vals = cs.filter_map { |c| c[fase] }
        [fase, vals.any? ? (vals.sum / vals.size).round(1) : nil]
      end.to_h

      # Promedios de sub-fases de propagación (solo para lotes que pasaron por esa etapa)
      prop_vals = cs.filter_map { |c| c[:propagacion] }
      veg_puro_vals = cs.filter_map { |c| c[:vegetativo_puro] }

      {
        genetica_id:     gid,
        nombre:          g.nombre,
        lotes_con_datos: cs.size,
        propagacion:     prop_vals.any? ? (prop_vals.sum / prop_vals.size).round(1) : nil,
        vegetativo_puro: veg_puro_vals.any? ? (veg_puro_vals.sum / veg_puro_vals.size).round(1) : nil,
        **promedios,
      }
    end.sort_by { |r| r[:nombre] }

    # ── 3. COMPARATIVA — lotes finalizados por cepa ─────────────────
    lotes_finalizados = lotes.select { |l| l.rendimiento_real_g.present? }
    comparativa = lotes_finalizados.group_by(&:genetica_id).filter_map do |gid, ls|
      g = ls.first&.genetica
      next unless g && ls.size >= 2

      {
        genetica_id: gid,
        nombre:      g.nombre,
        lotes:       ls.map { |l|
          {
            id:                l.id,
            codigo:            l.codigo,
            rendimiento_g:     l.rendimiento_real_g&.to_f,
            objetivo_g:        l.rendimiento_objetivo_g&.to_f,
            plants_count:      l.plants_count,
            grow_type:         l.grow_type,
            light_type:        l.light_type,
            start_date:        l.start_date,
          }
        }.sort_by { |l| l[:rendimiento_g] || 0 }.reverse,
      }
    end.sort_by { |r| r[:nombre] }

    {
      perdidas:    perdidas_por_genetica,
      ciclos:      ciclos_por_genetica,
      comparativa: comparativa,
    }
  end

  # GET /api/analytics/ejecutivo
  # Resumen anual — KPIs del año en curso vs año anterior
  def ejecutivo
    unless %w[admin supervisor super_admin].include?(current_user.role)
      return render json: { error: 'No autorizado' }, status: :forbidden
    end

    club         = current_user.club
    año_actual   = Date.today.year
    año_anterior = año_actual - 1

    render json: {
      año:      año_actual,
      actual:   kpis_anuales(club, año_actual),
      anterior: kpis_anuales(club, año_anterior),
    }
  end

  # GET /api/analytics/pl_lotes
  # Para: admin, supervisor
  def pl_lotes
    unless %w[admin supervisor super_admin].include?(current_user.role)
      return render json: { error: 'No autorizado' }, status: :forbidden
    end

    club  = current_user.club
    lotes = club.lotes.includes(:genetica, :costo_lote).order(created_at: :desc)

    # Ingresos y gramos dispensados por lote — 2 queries para todos los lotes
    ingresos_por_lote = Dispensacion
      .joins(:stock)
      .where(stocks: { club_id: club.id })
      .where.not(stocks: { lote_id: nil })
      .group('stocks.lote_id')
      .sum('dispensaciones.cantidad * COALESCE(dispensaciones.precio_unitario_ars, 0)')

    gramos_disp_por_lote = Dispensacion
      .joins(:stock)
      .where(stocks: { club_id: club.id })
      .where.not(stocks: { lote_id: nil })
      .group('stocks.lote_id')
      .sum(:cantidad)

    filas = lotes.map do |l|
      c           = l.costo_lote
      ingresos    = ingresos_por_lote[l.id].to_f.round(2)
      costo_total = c&.costo_total.to_f
      margen      = (ingresos - costo_total).round(2)
      margen_pct  = ingresos > 0 ? (margen / ingresos * 100).round(1) : nil
      gramos_disp = gramos_disp_por_lote[l.id].to_f.round(3)
      {
        id:                 l.id,
        codigo:             l.codigo,
        genetica:           l.genetica&.nombre,
        estado:             l.estado,
        costo_total:        costo_total,
        costo_por_gramo:    c&.costo_por_gramo&.to_f,
        ingresos:           ingresos,
        gramos_dispensados: gramos_disp,
        ingreso_por_gramo:  gramos_disp > 0 ? (ingresos / gramos_disp).round(2) : nil,
        margen:             margen,
        margen_pct:         margen_pct,
        tiene_costos:       c.present?,
        tiene_ingresos:     ingresos > 0,
      }
    end

    render json: { lotes: filas }
  end

  def kpis_anuales(club, año)
    inicio = Date.new(año, 1, 1)
    fin    = Date.new(año, 12, 31)

    lotes_año = club.lotes
                    .where("EXTRACT(YEAR FROM COALESCE(start_date, created_at::date)) = ?", año)

    gramos_producidos = lotes_año.where.not(rendimiento_real_g: nil)
                                 .sum(:rendimiento_real_g).to_f.round(2)
    ciclos_cerrados   = lotes_año.where(estado: 'finalizado').count

    base_disps = Dispensacion.joins(:stock)
                             .where(stocks: { club_id: club.id })
                             .where(fecha_dispensacion: inicio..fin)

    ingresos           = base_disps.sum('dispensaciones.cantidad * COALESCE(dispensaciones.precio_unitario_ars, 0)').to_f.round(2)
    gramos_dispensados = base_disps.sum(:cantidad).to_f.round(2)

    costo_total = CostoLote.joins(:lote)
                           .where(lotes: { club_id: club.id })
                           .where("EXTRACT(YEAR FROM COALESCE(lotes.start_date, lotes.created_at::date)) = ?", año)
                           .sum(:costo_total).to_f.round(2)

    margen     = (ingresos - costo_total).round(2)
    margen_pct = ingresos > 0 ? (margen / ingresos * 100).round(1) : nil

    {
      gramos_producidos:,
      gramos_dispensados:,
      ingresos:,
      costo_total:,
      margen:,
      margen_pct:,
      ciclos_cerrados:,
    }
  end

  def pearson_r(xs, ys)
    n = xs.size
    return nil if n < 3

    mx = xs.sum.to_f / n
    my = ys.sum.to_f / n
    num = xs.zip(ys).sum { |x, y| (x - mx) * (y - my) }
    den = Math.sqrt(xs.sum { |x| (x - mx)**2 } * ys.sum { |y| (y - my)**2 })
    return nil if den < 1e-10
    (num / den).round(3)
  rescue
    nil
  end

  def regresion_lineal(xs, ys)
    n = xs.size
    return nil if n < 3

    r = pearson_r(xs, ys)
    return nil unless r

    mx = xs.sum.to_f / n
    my = ys.sum.to_f / n
    ss_xy = xs.zip(ys).sum { |x, y| (x - mx) * (y - my) }
    ss_xx = xs.sum { |x| (x - mx)**2 }
    return nil if ss_xx < 1e-10

    slope     = (ss_xy / ss_xx).round(4)
    intercept = (my - slope * mx).round(2)
    min_x     = xs.min.round(3)
    max_x     = xs.max.round(3)

    {
      r:,
      r_squared:   (r**2).round(3),
      slope:,
      intercept:,
      n:,
      x_min:       min_x,
      x_max:       max_x,
      y_at_xmin:   (slope * min_x + intercept).round(1),
      y_at_xmax:   (slope * max_x + intercept).round(1),
    }
  rescue
    nil
  end

  private :calcular_rendimiento_genetica, :calcular_dispensador, :kpis_anuales,
          :pearson_r, :regresion_lineal
end
