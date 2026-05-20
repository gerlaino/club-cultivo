class AlertaDetectorService
  RANGOS = {
    'vegetativo' => { ph: (5.8..6.2), ec: (0.8..1.4), temperatura: (20..28), humedad: (50..70) },
    'floracion'  => { ph: (6.0..6.5), ec: (1.4..2.2), temperatura: (20..26), humedad: (40..55) },
    'maduracion' => { ph: (6.0..6.5), ec: (1.2..1.8), temperatura: (18..24), humedad: (40..50) },
  }.freeze

  DIAS_SIN_REGISTRO = {
    'vegetativo' => 3,
    'floracion'  => 2,
    'maduracion' => 1,
    'cosecha'    => 1,
  }.freeze

  VENTANA_DEDUP_HORAS = 20

  def initialize(club)
    @club = club
  end

  def detectar!
    lotes = @club.lotes
                 .where.not(estado: %w[finalizado curado])
                 .includes(:registros_ambientales, :genetica)

    lotes.find_each do |lote|
      detectar_sin_registro(lote)
      detectar_rango_ambiental(lote)
      detectar_cosecha_pendiente(lote)
      detectar_tareas_vencidas(lote)
    end
  end

  private

  def crear_alerta(tipo:, lote: nil, severidad:, mensaje:, contexto: {})
    return if alerta_reciente?(tipo, lote&.id, contexto)

    @club.alertas_internas.create!(
      tipo:             tipo,
      lote:             lote,
      severidad:        severidad,
      mensaje:          mensaje,
      destinada_a_role: 'admin',
      contexto:         contexto
    )
  end

  def alerta_reciente?(tipo, lote_id, contexto)
    scope = @club.alertas_internas
                 .where(tipo: tipo)
                 .where('created_at > ?', VENTANA_DEDUP_HORAS.hours.ago)
    scope = lote_id ? scope.where(lote_id: lote_id) : scope.where(lote_id: nil)

    if contexto[:tarea_id]
      scope = scope.where("contexto->>'tarea_id' = ?", contexto[:tarea_id].to_s)
    end

    scope.exists?
  end

  def detectar_sin_registro(lote)
    umbral = DIAS_SIN_REGISTRO[lote.estado] || 3
    ultimo = lote.registros_ambientales.maximum(:registrado_en)
    dias   = ultimo ? (Date.current - ultimo.to_date).to_i : 999
    return unless dias > umbral

    sev = dias > umbral * 2 ? 'error' : 'warning'
    crear_alerta(
      tipo:      'sin_registro_ambiental',
      lote:      lote,
      severidad: sev,
      mensaje:   "#{lote.codigo} lleva #{dias} días sin registro ambiental (máx. recomendado: #{umbral}d en #{lote.estado})",
      contexto:  { dias: dias, umbral: umbral, estado: lote.estado }
    )
  end

  def detectar_rango_ambiental(lote)
    rangos = RANGOS[lote.estado]
    return unless rangos

    ultimos = lote.registros_ambientales.order(registrado_en: :desc).limit(3).to_a
    return if ultimos.empty?

    rangos.each do |campo, rango|
      valores = ultimos.filter_map(&campo)
      next if valores.size < 2

      fuera = valores.count { |v| !rango.include?(v) }
      next unless fuera >= 2

      avg  = (valores.sum / valores.size.to_f).round(2)
      tipo = "#{campo}_fuera_rango"
      sev  = fuera == valores.size ? 'error' : 'warning'
      crear_alerta(
        tipo:      tipo,
        lote:      lote,
        severidad: sev,
        mensaje:   "#{lote.codigo}: #{campo} promedio #{avg} fuera de rango #{rango.min}–#{rango.max} (#{lote.estado}). #{fuera}/#{valores.size} registros afectados.",
        contexto:  { campo: campo.to_s, avg: avg, rango_min: rango.min, rango_max: rango.max, valores: valores }
      )
    end
  end

  def detectar_cosecha_pendiente(lote)
    return unless lote.estado == 'floracion' && lote.start_date.present? && lote.semanas_floracion.present?

    fecha_est    = lote.start_date + lote.semanas_floracion.weeks
    dias_pasados = (Date.current - fecha_est).to_i
    return unless dias_pasados > 0

    sev = dias_pasados > 7 ? 'error' : 'warning'
    crear_alerta(
      tipo:      'cosecha_pendiente',
      lote:      lote,
      severidad: sev,
      mensaje:   "#{lote.codigo} completó sus #{lote.semanas_floracion} semanas estimadas de floración hace #{dias_pasados} días.",
      contexto:  { dias_pasados: dias_pasados, semanas_floracion: lote.semanas_floracion }
    )
  end

  def detectar_tareas_vencidas(lote)
    @club.tareas
         .where(lote_id: lote.id)
         .where(estado: %w[pendiente en_progreso])
         .where(prioridad: %w[alta urgente])
         .where('fecha_programada < ?', 2.days.ago)
         .find_each do |tarea|
      dias = (Date.current - tarea.fecha_programada).to_i
      crear_alerta(
        tipo:      'tarea_vencida_cultivo',
        lote:      lote,
        severidad: tarea.prioridad == 'urgente' ? 'error' : 'warning',
        mensaje:   "Tarea '#{tarea.titulo}' (#{tarea.prioridad}) vencida hace #{dias} días en #{lote.codigo}.",
        contexto:  { tarea_id: tarea.id, titulo: tarea.titulo, dias: dias, prioridad: tarea.prioridad }
      )
    end
  end
end
