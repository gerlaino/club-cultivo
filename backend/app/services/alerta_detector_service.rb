class AlertaDetectorService
  # Rangos de fallback cuando el club no tiene setpoints configurados
  RANGOS = {
    # El ENRAIZADO es el opuesto del vegetativo, no una versión temprana. La planta todavía no
    # tiene raíz funcional: no absorbe (por eso EC ~0 — darle nutrientes le quema el callo) y no
    # puede reponer lo que transpira (por eso humedad altísima; a 60% se deshidrata y no prende).
    # La temperatura de SUSTRATO es la variable que decide si prende, más que la del aire: por
    # debajo de 22 °C el enraizado se frena aunque el cuarto esté perfecto.
    'enraizado'  => { ph: (5.5..6.0), ec: (0.0..0.6), temperatura: (22..26), humedad: (85..95),
                      temperatura_sustrato: (24..26) },
    'vegetativo' => { ph: (5.8..6.2), ec: (0.8..1.4), temperatura: (20..28), humedad: (50..70) },
    'floracion'  => { ph: (6.0..6.5), ec: (1.4..2.2), temperatura: (20..26), humedad: (40..55) },
  }.freeze

  # temperatura_sustrato entra al monitoreo por el enraizado. Para las fases que no declaran rango
  # (vegetativo, floración) `rango_para` devuelve nil y el campo se saltea: no hay falsas alarmas.
  CAMPOS_MONITOREADOS = %i[ph ec temperatura humedad temperatura_sustrato].freeze

  DIAS_SIN_REGISTRO = {
    'enraizado'  => 1,   # la etapa más frágil del ciclo: se mira todos los días
    'vegetativo' => 3,
    'floracion'  => 2,
    'cosecha'    => 1,
  }.freeze

  VENTANA_DEDUP_HORAS = 20

  def initialize(club)
    @club = club
  end

  # El detector es MIXTO: los cuatro detectores por lote son de la suite Cultivo y el de saldo
  # es de Producción y dispensa. Un club que compró sólo una de las dos no tiene por qué
  # recibir alertas de la otra, así que el filtro va acá y no en el job que lo llama.
  def detectar!
    detectar_cultivo if @club.feature?(:cultivo)
    detectar_saldo_cc_bajo if @club.feature?(:produccion_dispensa)
  end

  private

  def detectar_cultivo
    # Precargamos todos los setpoints del club para evitar N+1 por lote
    setpoints_club = SetpointFase.del_club(@club.id).to_a

    lotes = @club.lotes
                 .where.not(estado: %w[finalizado curado])
                 .includes(:registros_ambientales, :genetica)

    lotes.find_each do |lote|
      detectar_sin_registro(lote)
      detectar_rango_ambiental(lote, setpoints_club)
      detectar_cosecha_pendiente(lote)
      detectar_tareas_vencidas(lote)
    end
  end

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
    if contexto[:paciente_id]
      scope = scope.where("contexto->>'paciente_id' = ?", contexto[:paciente_id].to_s)
    end

    scope.exists?
  end

  def detectar_sin_registro(lote)
    umbral = dias_sin_registro_para(lote.estado)
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

  def detectar_rango_ambiental(lote, setpoints_club)
    ultimos = lote.registros_ambientales.order(registrado_en: :desc).limit(3).to_a
    return if ultimos.empty?

    CAMPOS_MONITOREADOS.each do |campo|
      rango = rango_para(campo, lote.estado, lote.genetica_id, setpoints_club)
      next unless rango

      valores = ultimos.filter_map { |r| v = r.public_send(campo); v&.to_f }
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

  # Devuelve el rango a usar para un campo/fase dado: prioriza setpoints del club,
  # cae a RANGOS (defaults) si no hay configuración.
  def dias_sin_registro_para(estado)
    cfg  = @club.alertas_config || {}
    fase = fase_setpoint(estado)
    # Se mira la config por el estado crudo primero (para no romper lo que un club ya haya
    # configurado) y después por la fase efectiva.
    (cfg.dig('dias_sin_registro', estado) || cfg.dig('dias_sin_registro', fase) ||
     DIAS_SIN_REGISTRO[fase] || 3).to_i
  end

  # germinación y esqueje son el mismo estadío —ENRAIZADO—, con dos orígenes. Antes se los mandaba
  # a los setpoints de 'vegetativo' con el argumento de que "comparten fisiología", y es al revés:
  # con el rango de vegetativo (humedad 50-70%) un propagador a 60% —donde los esquejes se
  # deshidratan— no disparaba NADA, y su EC casi nula disparaba una falsa alarma de EC baja.
  # Ciego para el problema real y gritando por el que no existe.
  def fase_setpoint(estado)
    estado
  end

  def rango_para(campo, fase, genetica_id, setpoints_club)
    fase = fase_setpoint(fase)
    sp = setpoints_club.find do |s|
      s.fase == fase &&
        s.tipo_lectura == campo.to_s &&
        s.valor_min.present? &&
        s.valor_max.present? &&
        (s.genetica_id.nil? || s.genetica_id == genetica_id)
    end
    # Si hay dos matches (genérica + específica de cepa), preferir la específica
    if genetica_id.present?
      sp_especifico = setpoints_club.find { |s| s.fase == fase && s.tipo_lectura == campo.to_s && s.genetica_id == genetica_id && s.valor_min.present? && s.valor_max.present? }
      sp = sp_especifico if sp_especifico
    end

    if sp
      (sp.valor_min.to_f..sp.valor_max.to_f)
    else
      RANGOS.dig(fase, campo)
    end
  end

  def detectar_cosecha_pendiente(lote)
    dias_obj = lote.dias_floracion_objetivo || (lote.semanas_floracion && lote.semanas_floracion * 7)
    return unless lote.estado == 'floracion' && dias_obj.present?

    # La floración se cuenta DESDE EL FLIP a 12/12, no desde el esqueje. Anclado en start_date, a
    # los días de floración se les descontaba todo el vegetativo y la alerta saltaba ~un mes antes.
    inicio_flora = lote.fecha_inicio_floracion
    return if inicio_flora.blank?

    fecha_est    = inicio_flora + dias_obj.days
    dias_pasados = (Date.current - fecha_est).to_i
    umbral_cosecha = (@club.alertas_config&.dig('cosecha_pendiente_umbral_dias') || 0).to_i
    return unless dias_pasados > umbral_cosecha

    sev = dias_pasados > 7 ? 'error' : 'warning'
    crear_alerta(
      tipo:      'cosecha_pendiente',
      lote:      lote,
      severidad: sev,
      mensaje:   "#{lote.codigo} completó sus #{dias_obj} días estimados de floración hace #{dias_pasados} días.",
      contexto:  { dias_pasados: dias_pasados, dias_floracion_objetivo: dias_obj }
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

  def detectar_saldo_cc_bajo
    @club.pacientes
         .joins(:cuenta_corriente)
         .where('cuenta_corrientes.limite_credito > 0')
         .includes(:cuenta_corriente)
         .find_each do |paciente|
      cc = paciente.cuenta_corriente

      # Saldo en dinero: margen = saldo_disponible + limite_credito
      # Si margen < 20% del límite → warning; si margen <= 0 → error
      margen = cc.saldo_disponible + cc.limite_credito
      pct    = (margen / cc.limite_credito * 100).round(0)
      if pct <= 0
        crear_alerta(
          tipo:      'saldo_cc_bajo',
          severidad: 'error',
          mensaje:   "#{paciente.nombre_completo} agotó el crédito en cuenta corriente.",
          contexto:  { paciente_id: paciente.id, margen: margen.to_f, pct: pct }
        )
      elsif pct <= 20
        crear_alerta(
          tipo:      'saldo_cc_bajo',
          severidad: 'warning',
          mensaje:   "#{paciente.nombre_completo} tiene solo #{pct}% de crédito disponible (#{margen.round(2)} ARS).",
          contexto:  { paciente_id: paciente.id, margen: margen.to_f, pct: pct }
        )
      end

      # Gramos: si activo y saldo <= 20% del límite
      next unless cc.credito_gramos_activo? && cc.limite_credito_g.to_d > 0
      pct_g = (cc.saldo_disponible_g.to_d / cc.limite_credito_g * 100).round(0)
      next unless pct_g <= 20

      sev = pct_g <= 0 ? 'error' : 'warning'
      crear_alerta(
        tipo:      'saldo_gramos_bajo',
        severidad: sev,
        mensaje:   "#{paciente.nombre_completo} tiene #{pct_g <= 0 ? 'sin' : "#{pct_g}%"} saldo en crédito gramos (#{cc.saldo_disponible_g.to_f.round(1)}g).",
        contexto:  { paciente_id: paciente.id, saldo_g: cc.saldo_disponible_g.to_f, pct_g: pct_g }
      )
    end
  end
end
