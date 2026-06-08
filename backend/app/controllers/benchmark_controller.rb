class BenchmarkController < ApplicationController
  before_action :authenticate_user!

  # GET /api/benchmark
  # Solo admin del club — ve sus propias métricas vs el agregado de la plataforma
  def show
    unless current_user.role == 'admin'
      return render json: { error: 'No autorizado' }, status: :forbidden
    end

    club = current_user.club

    render json: {
      opt_in:    club.benchmark_opt_in,
      mi_club:   metricas_club(club),
      plataforma: metricas_plataforma,
    }
  end

  private

  def metricas_club(club)
    pacientes_activos = club.pacientes.where(deleted_at: nil).count

    lotes = club.lotes.where.not(estado: 'germinacion')
    lotes_finalizados = lotes.select { |l| l.rendimiento_real_g.present? }
    rendimiento_promedio = lotes_finalizados.any? ?
      (lotes_finalizados.sum { |l| l.rendimiento_real_g.to_f } / lotes_finalizados.size).round(1) : nil

    hoy = Date.today
    disps_mes = Dispensacion.joins(stock: :sede)
                            .where(sedes: { club_id: club.id })
                            .where(fecha_dispensacion: hoy.beginning_of_month..hoy)
    gramos_mes = disps_mes.sum(:cantidad).to_f.round(2)
    dispens_por_paciente = pacientes_activos > 0 ? (disps_mes.count.to_f / pacientes_activos).round(2) : nil

    geneticas_activas = lotes.select { |l| %w[vegetativo floracion secado curado].include?(l.estado) }
                             .map(&:genetica_id).uniq.size

    {
      pacientes_activos:        pacientes_activos,
      lotes_totales:            lotes.count,
      lotes_finalizados:        lotes_finalizados.size,
      rendimiento_promedio_g:   rendimiento_promedio,
      gramos_dispensados_mes:   gramos_mes,
      dispens_por_paciente_mes: dispens_por_paciente,
      geneticas_activas:        geneticas_activas,
    }
  end

  def metricas_plataforma
    opted_clubs = Club.where(benchmark_opt_in: true)
    return nil if opted_clubs.empty?

    total_clubes = opted_clubs.count

    pacientes_counts = opted_clubs.map { |c| c.pacientes.where(deleted_at: nil).count }
    avg_pacientes = (pacientes_counts.sum.to_f / total_clubes).round(1)

    hoy = Date.today
    inicio_mes = hoy.beginning_of_month

    rendimientos = opted_clubs.flat_map do |c|
      c.lotes.where.not(estado: 'germinacion')
       .select { |l| l.rendimiento_real_g.present? }
       .map { |l| l.rendimiento_real_g.to_f }
    end
    avg_rendimiento = rendimientos.any? ? (rendimientos.sum / rendimientos.size).round(1) : nil

    gramos_mes_list = opted_clubs.map do |c|
      Dispensacion.joins(stock: :sede)
                  .where(sedes: { club_id: c.id })
                  .where(fecha_dispensacion: inicio_mes..hoy)
                  .sum(:cantidad).to_f
    end
    avg_gramos_mes = (gramos_mes_list.sum / total_clubes).round(2)

    dispens_por_pac_list = opted_clubs.filter_map do |c|
      pac = c.pacientes.where(deleted_at: nil).count
      next if pac == 0
      disps = Dispensacion.joins(stock: :sede)
                          .where(sedes: { club_id: c.id })
                          .where(fecha_dispensacion: inicio_mes..hoy)
                          .count
      (disps.to_f / pac).round(2)
    end
    avg_dispens_por_pac = dispens_por_pac_list.any? ?
      (dispens_por_pac_list.sum / dispens_por_pac_list.size).round(2) : nil

    {
      clubes_participantes:     total_clubes,
      avg_pacientes_activos:    avg_pacientes,
      avg_rendimiento_g:        avg_rendimiento,
      avg_gramos_mes:           avg_gramos_mes,
      avg_dispens_por_paciente: avg_dispens_por_pac,
    }
  end
end
