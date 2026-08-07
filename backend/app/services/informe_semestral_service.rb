class InformeSemestralService
  def initialize(club, anio:, semestre:)
    @club     = club
    @anio     = anio
    @semestre = semestre
    @desde    = semestre == 1 ? Date.new(anio, 1, 1)  : Date.new(anio, 7, 1)
    @hasta    = semestre == 1 ? Date.new(anio, 6, 30) : Date.new(anio, 12, 31)
  end

  def call
    {
      periodo:           { anio: @anio, semestre: @semestre, desde: @desde, hasta: @hasta },
      club:              datos_club,
      pacientes:         datos_pacientes,
      produccion:        datos_produccion,
      dispensaciones:    datos_dispensaciones,
      resumen_geneticas: resumen_geneticas,
      generado_en:       Time.current,
    }
  end

  private

  def datos_club
    {
      nombre:       @club.name,
      nombre_legal: @club.legal_name,
      email:        @club.email,
      telefono:     @club.phone,
      direccion:    @club.address,
      ciudad:       @club.city,
      provincia:    @club.state,
      pais:         @club.country,
      sedes_reprocann: @club.sedes.where(declarada_reprocann: true).map { |s|
        {
          nombre:    s.nombre,
          tipo:      s.tipo_label,
          direccion: [s.direccion, s.ciudad, s.provincia].compact.reject(&:empty?).join(', '),
        }
      },
    }
  end

  def datos_pacientes
    pacientes  = @club.pacientes.with_deleted.where('created_at <= ?', @hasta.end_of_day)
    activos    = pacientes.where(deleted_at: nil)
    con_repro  = activos.where.not(reprocann_numero: [nil, ''])
    vencidos   = activos.where('reprocann_vencimiento < ?', Time.zone.today)
                        .where.not(reprocann_vencimiento: nil)
    por_vencer = activos.reprocann_por_vencer

    {
      total:         activos.count,
      con_reprocann: con_repro.count,
      sin_reprocann: activos.where(reprocann_numero: [nil, '']).count,
      vencidos:      vencidos.count,
      por_vencer:    por_vencer.count,
      nomina:        activos.order(:apellido, :nombre).map { |s| nomina_paciente(s) },
    }
  end

  def nomina_paciente(s)
    {
      nombre_completo:       s.nombre_completo,
      dni:                   s.dni,
      fecha_nacimiento:      s.fecha_nacimiento,
      reprocann_numero:      s.reprocann_numero || '—',
      reprocann_vencimiento: s.reprocann_vencimiento,
      reprocann_vigente:     s.reprocann_vencimiento.present? && s.reprocann_vencimiento >= Time.zone.today,
    }
  end

  def datos_produccion
    lote_ids           = @club.lotes.pluck(:id)
    plantas_scope      = Plant.where(lote_id: lote_ids)
    plantas_act        = plantas_scope.where.not(state: %w[cosechado descartada])

    lotes_periodo = @club.lotes
                         .where("start_date <= ? AND (estado NOT IN (?) OR start_date >= ?)",
                                @hasta, ['finalizado'], @desde)
                         .includes(:sala, :costo_lote, :genetica)
                         .order(:start_date)

    {
      plantas_totales:       plantas_act.count,
      plantas_en_floracion:  plantas_act.where(state: 'floracion').count,
      plantas_en_vegetativo: plantas_act.where(state: 'vegetativo').count,
      plantas_en_secado:     plantas_act.where(state: 'secado').count,
      salas_activas:         @club.salas.activas.count,
      lotes_periodo:         lotes_periodo.map { |l| datos_lote(l) },
    }
  end

  def datos_lote(lote)
    {
      codigo:            lote.codigo,
      estado:            lote.estado,
      start_date:        lote.start_date,
      strain:            lote.genetica&.nombre || lote.strain,
      plants_count:      lote.plants_count,
      sala:              lote.sala&.nombre,
      costo_por_gramo:   lote.costo_lote&.costo_por_gramo&.to_f,
      gramos_producidos: lote.costo_lote&.gramos_producidos&.to_f,
    }
  end

  def datos_dispensaciones
    disps = Dispensacion.joins(:paciente)
                        .where(pacientes: { club_id: @club.id })
                        .where(fecha_dispensacion: @desde..@hasta)
    por_forma = disps.joins(:stock)
                     .group('stocks.forma_producto')
                     .sum('dispensaciones.cantidad')
                     .map { |forma, g| { tipo: forma, gramos: g.to_f.round(2) } }
    {
      total:                 disps.count,
      total_gramos:          disps.sum(:cantidad).to_f.round(2),
      por_tipo_producto:     por_forma,
      aporte_total_ars:      disps.sum(:aporte_socio_ars).to_f.round(2),
      pacientes_dispensados: disps.distinct.count(:paciente_id),
    }
  end

  def resumen_geneticas
    lotes = @club.lotes.includes(:genetica, :costo_lote)
    return [] if lotes.empty?

    groups = {}
    lotes.each do |lote|
      nombre = lote.genetica&.nombre.presence || lote.strain.presence
      next if nombre.blank?
      key = nombre.downcase
      groups[key] ||= { nombre: nombre, lote_ids: [], gramos_producidos: 0.0, lotes_count: 0 }
      groups[key][:lote_ids] << lote.id
      groups[key][:lotes_count] += 1
      groups[key][:gramos_producidos] += (lote.costo_lote&.gramos_producidos&.to_f || 0.0)
    end
    return [] if groups.empty?

    all_lote_ids       = groups.values.flat_map { |g| g[:lote_ids] }
    activas_por_lote   = Plant.where(lote_id: all_lote_ids).where.not(state: %w[cosechado descartada]).group(:lote_id).count
    cosechadas_por_lote = Plant.where(lote_id: all_lote_ids, state: 'cosechado').group(:lote_id).count

    groups.map do |_, g|
      activas    = g[:lote_ids].sum { |id| activas_por_lote[id] || 0 }
      cosechadas = g[:lote_ids].sum { |id| cosechadas_por_lote[id] || 0 }
      {
        nombre:             g[:nombre],
        plantas_activas:    activas,
        plantas_cosechadas: cosechadas,
        gramos_producidos:  g[:gramos_producidos].round(2),
        lotes_count:        g[:lotes_count],
      }
    end.sort_by { |g| -(g[:plantas_activas] + g[:plantas_cosechadas]) }
  end
end
