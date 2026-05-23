class AnalyticsController < ApplicationController
  before_action :authenticate_user!

  # GET /api/analytics/rendimiento_genetica
  # Para: cultivador, admin, supervisor
  def rendimiento_genetica
    unless %w[admin cultivador supervisor super_admin].include?(current_user.role)
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
        lotes_activos:        ls.count { |l| %w[vegetativo floracion secado curado].include?(l.estado) },
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
    }
  end

  # GET /api/analytics/produccion
  # Para: admin, cultivador
  def produccion
    unless %w[admin cultivador supervisor super_admin].include?(current_user.role)
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

      # Armamos un mapa fase => timestamp_inicio
      fase_inicio = {}
      fase_inicio['vegetativo'] = l.start_date&.to_time

      evs.each do |ev|
        fase_inicio[ev.estado_nuevo] = ev.registrado_en if ev.estado_nuevo.present?
      end

      fases = %w[vegetativo floracion cosecha secado curado]
      dias = {}
      fases.each_with_index do |fase, idx|
        inicio = fase_inicio[fase]
        siguiente = fases[idx + 1]
        fin = siguiente ? fase_inicio[siguiente] : nil

        # Para lotes finalizados con fin conocido; o si lote está en esa fase (usar hoy)
        fin ||= Time.current if l.estado == fase

        dias[fase] = inicio && fin ? ((fin - inicio) / 86400.0).round(1) : nil
      end

      next if dias.values.all?(&:nil?)

      { lote_id: l.id, lote_codigo: l.codigo, genetica_id: l.genetica_id, **dias }
    end

    ciclos_por_genetica = ciclos_por_lote.group_by { |c| c[:genetica_id] }.filter_map do |gid, cs|
      g = lotes.find { |l| l.genetica_id == gid }&.genetica
      next unless g

      fases = %w[vegetativo floracion cosecha secado curado]
      promedios = fases.map do |fase|
        vals = cs.filter_map { |c| c[fase] }
        [fase, vals.any? ? (vals.sum / vals.size).round(1) : nil]
      end.to_h

      { genetica_id: gid, nombre: g.nombre, lotes_con_datos: cs.size, **promedios }
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

  private :calcular_rendimiento_genetica, :calcular_dispensador
end
