class InformesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_auditor_o_admin!

  PERIODO_RANGOS = {
    'mes_actual'   => -> { [Date.today.beginning_of_month, Date.today.end_of_month] },
    'mes_anterior' => -> { [1.month.ago.beginning_of_month, 1.month.ago.end_of_month] },
    'trimestre'    => -> { [3.months.ago.beginning_of_month, Date.today.end_of_month] },
    'anio'         => -> { [Date.today.beginning_of_year, Date.today.end_of_year] },
  }.freeze

  def reprocann
    club = current_user.club
    pacientes = Paciente.for_club(club.id)
    total = pacientes.count

    con_vigente  = pacientes.where('reprocann_vencimiento >= ?', Date.today).count
    vencen_30d   = pacientes.where('reprocann_vencimiento > ? AND reprocann_vencimiento <= ?',
                                    Date.today, 30.days.from_now).count
    vencidos     = pacientes.where('reprocann_vencimiento < ?', Date.today).count
    sin_reprocann = pacientes.where(reprocann_numero: nil).count

    lista = pacientes.limit(200).map do |p|
      estado = if p.reprocann_numero.blank?
        'sin_reprocann'
      elsif p.reprocann_vencimiento.nil?
        'vigente_sin_vencimiento'
      elsif p.reprocann_vencimiento < Date.today
        'vencido'
      elsif p.reprocann_vencimiento <= 30.days.from_now
        'por_vencer'
      else
        'vigente'
      end
      {
        iniciales:             "#{p.nombre[0]}.#{p.apellido[0]}.",
        dni_ultimos_4:         p.dni_normalizado.to_s.last(4),
        reprocann_estado:      estado,
        reprocann_vencimiento: p.reprocann_vencimiento,
      }
    end

    render json: {
      total_pacientes:        total,
      con_reprocann_vigente:  con_vigente,
      vencen_30d:             vencen_30d,
      vencidos:               vencidos,
      sin_reprocann:          sin_reprocann,
      lista_anonimizada:      lista,
    }
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

    por_estado = Lote::ESTADOS.map do |e|
      lotes_e = club.lotes.where(estado: e)
      gramos_e = Pesada.joins(:lote)
                       .where(lotes: { club_id: club.id, estado: e }, fase_destino: 'finalizado')
                       .sum('COALESCE(peso_curado_g, 0)').to_f
      { estado: e, lotes: lotes_e.count, plantas: 0, gramos: gramos_e }
    end.reject { |r| r[:lotes].zero? }

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

    disps = Dispensacion.joins(stock: :sede)
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
      stock_g = Stock.joins(:sede).where(sede: s).disponibles.sum(:cantidad).to_f rescue 0
      {
        nombre:          s.nombre,
        salas:           s.salas.count,
        plantas:         plantas,
        stock_disponible: stock_g,
      }
    end

    sedes_activas  = sedes.where(activa: true).count rescue sedes.count
    salas_totales  = sedes.sum { |s| s.salas.count }
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

    pacientes = Paciente.for_club(club.id)
    con_vigente  = pacientes.where('reprocann_vencimiento >= ?', Date.today).count
    vencen_30d   = pacientes.where('reprocann_vencimiento > ? AND reprocann_vencimiento <= ?',
                                    Date.today, 30.days.from_now).count
    vencidos     = pacientes.where('reprocann_vencimiento < ?', Date.today).count
    sin_seg      = pacientes.where(con_seguimiento_medico: false).count

    total_pax = pacientes.count
    tasa = total_pax.positive? ? ((con_vigente.to_f / total_pax) * 100).round(1) : 0

    disp_sobre_limite = Dispensacion
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
      dispensaciones_sobre_limite:     disp_sobre_limite,
      tasa_cumplimiento:               tasa,
      alertas:                         alertas,
    }
  end

  private

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
