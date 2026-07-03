class LoteSerializer
  def self.serialize(lote, include_plants: false, include_cycle_data: false)
    idx_ciclo    = Lote::CICLO_FASES.index(lote.estado)
    proxima_fase = if %w[semilla esqueje].include?(lote.estado)
      'vegetativo'
    elsif idx_ciclo
      Lote::CICLO_FASES[idx_ciclo + 1]
    end
    puede_transicion = %w[semilla esqueje].include?(lote.estado) ||
                       (idx_ciclo.present? && idx_ciclo < Lote::CICLO_FASES.length - 1)

    eventos       = lote.lote_eventos.loaded? ? lote.lote_eventos : lote.lote_eventos.to_a
    ev_vegetativo = eventos.select { |e| e.tipo == 'cambio_estado' && e.estado_nuevo == 'vegetativo' }.min_by(&:registrado_en)
    ev_floracion  = eventos.select { |e| e.tipo == 'cambio_estado' && e.estado_nuevo == 'floracion' }.min_by(&:registrado_en)
    ev_cosecha    = eventos.select { |e| e.tipo == 'cambio_estado' && e.estado_nuevo == 'cosecha'   }.min_by(&:registrado_en)

    fecha_inicio_vegetativo = ev_vegetativo&.registrado_en&.to_date
    fecha_inicio_floracion  = ev_floracion&.registrado_en&.to_date
    fecha_cosechado         = ev_cosecha&.registrado_en&.to_date

    dias_vegetacion = (lote.start_date && fecha_inicio_floracion) ? (fecha_inicio_floracion - lote.start_date).to_i : nil
    dias_floracion  = (fecha_inicio_floracion && fecha_cosechado)  ? (fecha_cosechado - fecha_inicio_floracion).to_i   : nil

    # Días en cosecha: desde que se cosechó hasta que el lote se transforma en stock o
    # pasa a curado (lo que ocurra primero); si sigue en cosecha, hasta hoy.
    dias_secado = if fecha_cosechado
      ev_curado    = eventos.select { |e| e.tipo == 'cambio_estado' && e.estado_nuevo == 'curado' }.min_by(&:registrado_en)
      fin_cosecha  = [ev_curado&.registrado_en&.to_date, lote.stocks.minimum(:created_at)&.to_date].compact.min || Date.current
      (fin_cosecha - fecha_cosechado).to_i
    end

    # Días en el estado actual: desde el último cambio a este estado (o desde el
    # inicio del lote si nunca cambió de estado, ej. creado en vegetativo/semilla).
    ev_estado_actual = eventos.select { |e| e.tipo == 'cambio_estado' && e.estado_nuevo == lote.estado }.max_by(&:registrado_en)
    fecha_estado_actual = ev_estado_actual&.registrado_en&.to_date || lote.start_date
    dias_en_estado   = fecha_estado_actual ? (Date.current - fecha_estado_actual).to_i : nil

    result = {
      id:                   lote.id,
      club_id:              lote.club_id,
      sala_id:              lote.sala_id,
      codigo:               lote.codigo,
      codigo_qr:            lote.codigo_qr,
      origen:               lote.origen,
      planta_madre:         lote.planta_madre ? { id: lote.planta_madre.id, nombre: lote.planta_madre.nombre, codigo_qr: lote.planta_madre.codigo_qr } : nil,
      planta_madre_ids:     lote.planta_madre_ids || [],
      estado:               lote.estado,
      fase:                 lote.estado,
      proxima_fase_posible: proxima_fase,
      puede_transicionar:   puede_transicion,
      start_date:           lote.start_date,
      plants_count:            lote.plants_count,
      plantas_seleccion_count: lote.plants.where(es_seleccion: true).count,
      plantas_cosechadas_count: lote.estado == 'floracion' ? lote.plants.where(state: 'cosechado').count : nil,
      strain:             lote.strain,
      notes:              lote.notes,
      grow_type:                 lote.grow_type,
      light_type:                lote.light_type,
      semanas_floracion:         lote.semanas_floracion, # deprecado
      dias_vegetativo_objetivo:  lote.dias_vegetativo_objetivo,
      dias_floracion_objetivo:   lote.dias_floracion_objetivo,
      dias_cosecha_objetivo:     lote.dias_cosecha_objetivo,
      tamanio_maceta:            lote.tamanio_maceta,
      tamanio_maceta_inicial:    lote.tamanio_maceta_inicial,
      fecha_trasplante:          lote.fecha_trasplante,
      fotoperiodo:               lote.fotoperiodo,
      fotoperiodo_vegetativo:    lote.fotoperiodo_vegetativo,
      ph_riego:                  lote.ph_riego&.to_f,
      fertilizacion_descripcion: lote.fertilizacion_descripcion,
      sistema_hidro:             lote.sistema_hidro,
      sustrato_especifico:       lote.sustrato_especifico,
      genetica_id:        lote.genetica_id,
      genetica:           lote.genetica ? { id: lote.genetica.id, nombre: lote.genetica.nombre, tipo: lote.genetica.tipo, registrada_inase: lote.genetica.registrada_inase } : nil,
      dias_desde_inicio:  lote.dias_desde_inicio,
      dias_en_estado:     dias_en_estado,
      progreso_ciclo:     lote.progreso_ciclo,
      costo_por_gramo:    lote.costo_lote&.costo_por_gramo&.to_f,
      costo_total:        lote.costo_lote&.costo_total&.to_f,
      gramos_producidos:  lote.costo_lote&.gramos_producidos&.to_f,
      tiene_costo:        lote.costo_lote.present?,
      plants_count_objetivo:  lote.plants_count_objetivo,
      rendimiento_objetivo_g: lote.rendimiento_objetivo_g&.to_f,
      fecha_cosecha_estimada: lote.fecha_cosecha_estimada,
      fecha_inicio_vegetativo: fecha_inicio_vegetativo,
      fecha_inicio_floracion:  fecha_inicio_floracion,
      fecha_cosechado:        fecha_cosechado,
      dias_vegetacion:        dias_vegetacion,
      dias_floracion:         dias_floracion,
      dias_secado:         dias_secado,
      rendimiento_real_g:     lote.rendimiento_real_g&.to_f,
      plants_count_cosechadas: lote.plants_count_cosechadas,
      manicurador_id: lote.manicurador_id,
      manicurador:    lote.manicurador ? { id: lote.manicurador.id, nombre: lote.manicurador.first_name || lote.manicurador.email } : nil,
      sala: lote.sala ? {
        id:     lote.sala.id,
        nombre: lote.sala.nombre,
        tipo:   lote.sala.tipo,
        sede:   lote.sala.sede ? { id: lote.sala.sede_id, nombre: lote.sala.sede.nombre } : nil,
      } : nil,
      # El lote tiene sede propia (post-cosecha no tiene sala). Fallback a la sala.
      sede_id: lote.sede_id || lote.sala&.sede_id,
      sede:    (lote.sede || lote.sala&.sede) ? { id: (lote.sede_id || lote.sala&.sede_id), nombre: (lote.sede || lote.sala&.sede)&.nombre } : nil,
      created_at: lote.created_at,
      updated_at: lote.updated_at,
    }

    pm = lote.pesadas.loaded? \
      ? lote.pesadas.select(&:manicurado).max_by { |p| p.registrado_at } \
      : lote.pesadas.where(manicurado: true).order(registrado_at: :desc).first
    if pm
      # QR flow may leave peso_seco_g nil — fall back to sum of pesadas_plantas
      pm_peso = pm.peso_seco_g&.to_f
      pm_peso = pm.pesadas_plantas.sum(:peso_seco_g).to_f.round(2) if pm_peso.nil? || pm_peso == 0
      pm_peso = nil if pm_peso == 0.0
      result[:ultima_pesada_manicura] = {
        peso_seco_g:         pm_peso,
        plantas_manicuradas: pm.plantas_manicuradas || pm.pesadas_plantas.count,
        notas:               pm.notas,
        registrado_at:       pm.registrado_at,
        registrado_por:      pm.registrado_por&.first_name,
        aprobada_at:         pm.aprobada_at,
      }
    else
      result[:ultima_pesada_manicura] = nil
    end

    ultima_p = lote.pesadas.loaded? \
      ? lote.pesadas.max_by { |p| p.registrado_at } \
      : lote.pesadas.order(registrado_at: :desc).first
    result[:peso_final_g] = ultima_p&.peso_curado_g&.to_f || ultima_p&.peso_seco_g&.to_f

    if include_cycle_data
      result[:pesadas] = lote.pesadas.includes(:registrado_por, pesadas_plantas: :plant).map { |p| PesadaSerializer.serialize(p) }
      result[:stocks]  = lote.stocks.includes(:sede).map { |s| StockSerializer.serialize_inline(s) }
    end

    if include_plants
      has_pasada_col = Plant.column_names.include?('pasada_cosecha')
      result[:plants] = lote.plants.order(:nombre).map { |p|
        { id: p.id, nombre: p.nombre, codigo_qr: p.codigo_qr, state: p.state,
          es_seleccion: p.es_seleccion,
          fecha_cosecha:  p.fecha_cosecha,
          pasada_cosecha: has_pasada_col ? p.pasada_cosecha : nil }
      }
      result[:plantas_en_floracion] = lote.plants.where(state: 'floracion').count
      result[:pasadas_cosecha] = if has_pasada_col
        lote.plants.where.not(pasada_cosecha: nil)
            .group(:pasada_cosecha).count
            .sort.map { |pasada, cnt| { pasada: pasada, plantas: cnt } }
      else
        []
      end

      salas_base = lote.club.salas.activas
      salas_base = case proxima_fase
        when 'cosecha'    then salas_base.where('tipo = ? OR kind = ?', 'cosecha', 'cosecha')
        when 'vegetativo' then salas_base.where('tipo = ? OR kind = ?', 'vegetativo', 'vegetativo')
        when 'floracion'  then salas_base.where('tipo = ? OR kind = ?', 'floracion',  'floracion')
        else salas_base
      end
      result[:salas_destino] = salas_base
                                    .includes(:responsable, :sede)
                                    .order(:nombre)
                                    .map { |s| {
                                      id:                 s.id,
                                      nombre:             s.nombre,
                                      kind:               s.kind,
                                      sede_id:            s.sede_id,
                                      sede:               s.sede ? { id: s.sede_id, nombre: s.sede.nombre } : nil,
                                      actual:             s.id == lote.sala_id,
                                      responsable_id:     s.responsable_id,
                                      responsable_nombre: s.responsable&.nombre_completo,
                                    } }
    end

    result
  end
end
