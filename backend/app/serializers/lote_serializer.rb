class LoteSerializer
  def self.serialize(lote, include_plants: false, include_cycle_data: false)
    # Próxima fase según la secuencia de avance: germinación→esqueje→vegetativo→floración→cosecha.
    idx_avance   = Lote::AVANCE.index(lote.estado)
    proxima_fase = (idx_avance && idx_avance < Lote::AVANCE.length - 1) ? Lote::AVANCE[idx_avance + 1] : nil
    puede_transicion = proxima_fase.present?

    eventos       = lote.lote_eventos.loaded? ? lote.lote_eventos : lote.lote_eventos.to_a
    ev_vegetativo = eventos.select { |e| e.tipo == 'cambio_estado' && e.estado_nuevo == 'vegetativo' }.min_by(&:registrado_en)
    ev_floracion  = eventos.select { |e| e.tipo == 'cambio_estado' && e.estado_nuevo == 'floracion' }.min_by(&:registrado_en)
    ev_cosecha    = eventos.select { |e| e.tipo == 'cambio_estado' && e.estado_nuevo == 'cosecha'   }.min_by(&:registrado_en)

    fecha_inicio_vegetativo = ev_vegetativo&.registrado_en&.to_date
    fecha_inicio_floracion  = ev_floracion&.registrado_en&.to_date
    fecha_cosechado         = ev_cosecha&.registrado_en&.to_date

    # El vegetativo arranca cuando la planta entra a maceta, NO en el esqueje: en el propagador no
    # crece, emite raíz.
    #
    # Los lotes viejos y los heredados pasaron a vegetativo sin dejar el evento, así que ahí se cae a
    # `start_date`: es lo único que se sabe. Sin ese fallback un lote EN VEGETATIVO quedaba con
    # `dias_ciclo` nil y la ficha lo mostraba como "Enraizando · día 25". Mismo criterio que
    # `Lote#fecha_inicio_vegetativo` — si divergen, la ficha y la analítica cuentan distinto.
    inicio_vegetativo = fecha_inicio_vegetativo || (lote.estado == 'enraizado' ? nil : lote.start_date)
    dias_vegetacion  = (inicio_vegetativo && fecha_inicio_floracion) ? (fecha_inicio_floracion - inicio_vegetativo).to_i : nil
    # Días enraizando: del inicio hasta que prendió (o hasta hoy si todavía está en el propagador).
    dias_enraizado   = lote.start_date ? [((inicio_vegetativo || Date.current) - lote.start_date).to_i, 0].max : nil
    # El ciclo productivo. nil solo mientras enraíza: todavía no arrancó.
    dias_ciclo       = inicio_vegetativo ? (Date.current - inicio_vegetativo).to_i : nil
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
    # El cálculo vive en el modelo (`Lote#fecha_estado_actual`): lo miran esta tabla y el chatbot,
    # y con dos copias se contradecían — el chatbot decía "no tengo los días en floración"
    # mientras acá se mostraba "3d". Se reusan los eventos ya precargados para no re-consultar.
    ev_estado_actual = eventos.select { |e| e.tipo == 'cambio_estado' && e.estado_nuevo == lote.estado }.max_by(&:registrado_en)
    fecha_estado_actual = ev_estado_actual&.registrado_en&.to_date || lote.start_date
    dias_en_estado   = fecha_estado_actual ? (Date.current - fecha_estado_actual).to_i : nil

    # La línea de tiempo del lote: cuándo entró a cada estadío.
    #
    # Se toma la ÚLTIMA entrada a cada estado, no la primera, por el mismo motivo que
    # `fecha_estado_actual`: si un lote se avanzó por error y volvió atrás, lo que interesa es
    # desde cuándo está donde está. Con la primera, un lote que rebotó mostraría una fecha en la
    # que efectivamente ya no estaba en esa fase.
    #
    # OJO: `dias_floracion` de más arriba SÍ usa la primera entrada, y está bien —mide cuánto
    # duró la floración completa, que es otra pregunta—. No unificar las dos.
    historial_estados = eventos
      .select { |e| e.tipo == 'cambio_estado' && e.estado_nuevo.present? && e.registrado_en.present? }
      .group_by(&:estado_nuevo)
      .transform_values { |evs| evs.max_by(&:registrado_en).registrado_en.to_date }
      .map { |estado, fecha| { estado: estado, fecha: fecha } }
      .sort_by { |h| h[:fecha] }

    result = {
      id:                   lote.id,
      club_id:              lote.club_id,
      sala_id:              lote.sala_id,
      codigo:               lote.codigo,
      # De qué lote se desprendió, si nació separándose de otro. Sin esto el sufijo del código
      # (L-26-043-B) no dice de dónde salió y hay que adivinarlo.
      lote_origen:          (o = lote.lote_origen) && { id: o.id, codigo: o.codigo },
      desprendidos_count:   lote.desprendidos.size,
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
      # `nombre_visible` lleva la variedad declarada entre paréntesis: es lo que va en etiquetas
      # y pantallas internas. En los informes regulatorios se usa `nombre_declarado`, que es sólo
      # el del INASE.
      genetica:           lote.genetica ? { id: lote.genetica.id, nombre: lote.genetica.nombre, nombre_visible: lote.genetica.nombre_visible, tipo: lote.genetica.tipo, registrada_inase: lote.genetica.registrada_inase } : nil,
      dias_desde_inicio:  lote.dias_desde_inicio,
      dias_en_estado:     dias_en_estado,
      # Desde cuándo está en el estado actual. Sale del MISMO cálculo que `dias_en_estado`, así
      # que la fecha y los días de la tabla no pueden contradecirse.
      fecha_estado_actual: fecha_estado_actual,
      historial_estados:   historial_estados,
      # Panorama completo: "45 días de ciclo + 12 enraizando". Las métricas usan dias_ciclo.
      dias_enraizado:     dias_enraizado,
      dias_ciclo:         dias_ciclo,
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
