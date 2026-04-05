class InformeSemestralController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin_or_autorizado!

  # GET /informe_semestral
  def show
    club     = current_user.club
    anio     = (params[:anio]     || Date.today.year).to_i
    semestre = (params[:semestre] || (Date.today.month <= 6 ? 1 : 2)).to_i

    desde = semestre == 1 ? Date.new(anio, 1, 1)  : Date.new(anio, 7, 1)
    hasta = semestre == 1 ? Date.new(anio, 6, 30) : Date.new(anio, 12, 31)

    render json: {
      periodo:           { anio: anio, semestre: semestre, desde: desde, hasta: hasta },
      club:              datos_club(club),
      socios:            datos_socios(club, hasta),
      produccion:        datos_produccion(club, desde, hasta),
      dispensaciones:    datos_dispensaciones(club, desde, hasta),
      resumen_geneticas: resumen_geneticas(club, desde, hasta),
      generado_en:       Time.current,
      generado_por:      "#{current_user.first_name} #{current_user.last_name}".strip,
    }
  end

  private

  def datos_club(club)
    {
      nombre:       club.name,
      nombre_legal: club.legal_name,
      email:        club.email,
      telefono:     club.phone,
      direccion:    club.address,
      ciudad:       club.city,
      provincia:    club.state,
      pais:         club.country,
      sedes_reprocann: club.sedes.where(declarada_reprocann: true).map { |s|
        {
          nombre:    s.nombre,
          tipo:      s.tipo_label,
          direccion: [s.direccion, s.ciudad, s.provincia].compact.reject(&:empty?).join(", "),
        }
      },
    }
  end

  def datos_socios(club, hasta)
    socios     = club.socios.with_deleted.where("created_at <= ?", hasta.end_of_day)
    activos    = socios.where(deleted_at: nil)
    con_repro  = activos.where.not(reprocann_numero: [nil, ""])
    vencidos   = activos.where("reprocann_vencimiento < ?", Date.today)
                        .where.not(reprocann_vencimiento: nil)
    por_vencer = activos.reprocann_por_vencer

    {
      total:         activos.count,
      con_reprocann: con_repro.count,
      sin_reprocann: activos.where(reprocann_numero: [nil, ""]).count,
      vencidos:      vencidos.count,
      por_vencer:    por_vencer.count,
      nomina:        activos.order(:apellido, :nombre).map { |s| nomina_socio(s) },
    }
  end

  def nomina_socio(s)
    {
      nombre_completo:       s.nombre_completo,
      dni:                   s.dni,
      fecha_nacimiento:      s.fecha_nacimiento,
      reprocann_numero:      s.reprocann_numero || "—",
      reprocann_vencimiento: s.reprocann_vencimiento,
      reprocann_vigente:     s.reprocann_vencimiento.present? && s.reprocann_vencimiento >= Date.today,
    }
  end

  def datos_produccion(club, desde, hasta)
    lotes_ids = club.lotes.pluck(:id)

    total_plantas      = Plant.where(lote_id: lotes_ids).where.not(state: %w[cosechado descartada]).count
    plantas_floracion  = Plant.where(lote_id: lotes_ids, state: "floracion").count
    plantas_vegetativo = Plant.where(lote_id: lotes_ids, state: "vegetativo").count
    plantas_secado     = Plant.where(lote_id: lotes_ids, state: "secado").count

    lotes_periodo = club.lotes
                        .where("start_date <= ? AND (estado NOT IN (?) OR start_date >= ?)",
                               hasta, ["finalizado"], desde)
                        .includes(:sala, :costo_lote, :genetica)
                        .order(:start_date)

    {
      plantas_totales:       total_plantas,
      plantas_en_floracion:  plantas_floracion,
      plantas_en_vegetativo: plantas_vegetativo,
      plantas_en_secado:     plantas_secado,
      salas_activas:         club.salas.activas.count,
      lotes_periodo:         lotes_periodo.map { |l| datos_lote(l) },
    }
  end

  def datos_lote(lote)
    {
      codigo:               lote.codigo,
      estado:               lote.estado,
      start_date:           lote.start_date,
      strain:               lote.genetica&.nombre || lote.strain,
      grow_type:            lote.grow_type,
      light_type:           lote.light_type,
      plants_count:         lote.plants_count,
      sala:                 lote.sala&.nombre,
      costo_por_gramo:      lote.costo_lote&.costo_por_gramo&.to_f,
      gramos_producidos:    lote.costo_lote&.gramos_producidos&.to_f,
      tiene_cromatografico: lote.costo_lote.present?,
    }
  end

  def datos_dispensaciones(club, desde, hasta)
    disps = Dispensacion.joins(:socio)
                        .where(socios: { club_id: club.id })
                        .where(fecha_dispensacion: desde..hasta)
    {
      total:              disps.count,
      total_gramos:       disps.sum(:cantidad_gramos).to_f.round(2),
      por_tipo_producto:  disps.group(:tipo_producto).sum(:cantidad_gramos)
                               .map { |tipo, g| { tipo: tipo, gramos: g.to_f.round(2) } },
      aporte_total_ars:   disps.sum(:aporte_socio_ars).to_f.round(2),
      socios_dispensados: disps.distinct.count(:socio_id),
    }
  end

  # Solo genéticas que tienen plantas activas O tuvieron lotes en el período
  # Las genéticas INASE sin uso real no aparecen
  def resumen_geneticas(club, desde, hasta)
    lotes_ids = club.lotes.pluck(:id)

    # Genéticas con plantas vivas actualmente
    geneticas_con_plantas = Plant.where(lote_id: lotes_ids)
                                 .where.not(state: %w[cosechado descartada])
                                 .where.not(genetica_id: nil)
                                 .group(:genetica_id)
                                 .count

    # Genéticas usadas en lotes del período (aunque las plantas ya no estén)
    geneticas_en_periodo = club.lotes
                               .where("start_date <= ?", hasta)
                               .where.not(genetica_id: nil)
                               .pluck(:genetica_id)
                               .uniq

    # Unión de ambos sets
    genetica_ids = (geneticas_con_plantas.keys + geneticas_en_periodo).uniq

    return [] if genetica_ids.empty?

    club.geneticas.where(id: genetica_ids, activa: true).map do |g|
      plantas_activas = geneticas_con_plantas[g.id] || 0
      {
        nombre:          g.nombre,
        tipo:            g.tipo,
        thc:             g.thc&.to_f,
        cbd:             g.cbd&.to_f,
        registrada_inase: g.registrada_inase,
        plantas_activas: plantas_activas,
      }
    end.sort_by { |g| -g[:plantas_activas] }
  end

  def require_admin_or_autorizado!
    unless current_user.admin? || current_user.role.in?(%w[abogado auditor])
      render json: { error: "No autorizado" }, status: :forbidden
    end
  end
end