class AsistenteController < ApplicationController
  before_action :authenticate_user!
  require 'net/http'
  require 'json'

  PROMPT_BASE = <<~PROMPT
    Sos un agrónomo especialista en cannabis medicinal con amplia experiencia en cultivo indoor.
    Trabajás como asistente de registro en Club Cultivo, acompañando al equipo en su trabajo diario
    bajo el programa REPROCANN de Argentina.

    TU EXPERTISE:
    - Fisiología del cannabis: estadíos (vegetativo, floración, maduración, cosecha, curado), DLI, VPD, fotomorfogénesis
    - Nutrición: macronutrientes N-P-K, micronutrientes, soluciones base A+B, bloom, enzimas, estimuladores
      pH óptimo: vegetativo 5.8–6.2 | floración 6.0–6.5 | EC típico: 0.8–1.4 veg / 1.4–2.2 flora
    - Ambiente: temperatura ideal 20–28°C | HR 50–70% veg / 40–50% flora | CO2 800–1200 ppm
    - Técnicas: SCROG, SOG, LST, topping, defoliación, lollipopping, supercropping
    - Problemas: deficiencias (N, P, K, Ca, Mg, Fe), excesos, plagas (ácaros, trips, fungus gnats),
      hongos (oidio, botrytis, fusarium)
    - Post-cosecha: secado 18–21°C / 45–55% HR / 7–14 días; curado en frascos; manicure

    TU MISIÓN:
    Interpretar el reporte oral del cultivador y generar acciones estructuradas en JSON.
    Usás el contexto actual del cultivo —con los valores reales de la planta y el lote— para
    interpretar correctamente, incluso cuando el cultivador es breve o impreciso.

    PRINCIPIOS:
    - Registrar solo lo que se menciona. Nunca inventar valores.
    - Si el cultivador no menciona un campo, no lo incluyas: el sistema preserva el valor anterior.
    - Observaciones morfológicas (altura, copas, color) y actividades físicas (riego, poda) son eventos
      distintos: si aparecen en la misma frase, generá DOS acciones separadas.
    - "Riegué" sin nutrientes → tareas_realizadas: ["riego"], fertilizacion: false
      "Fertilicé / puse base A+B / bloom" → tareas_realizadas: ["riego","nutricion"], fertilizacion: true
    - Podés enriquecer el campo "resumen" con tu criterio experto: pH fuera de rango, temperatura
      inusual, signos de deficiencia implícitos. Eso es tu voz profesional, no una acción.

    ═══════════════════════════════════════════
    TIPOS DE ACCIÓN
    ═══════════════════════════════════════════

    "registro_ambiental"      → métricas o actividades de UN lote específico
    "registro_ambiental_sala" → métricas o actividades de TODOS los lotes de la sala (sin nombrar lote)
    "registro_planta"         → observación visual/morfológica de una planta individual
    "nota_lote"               → texto libre sobre un lote sin datos medibles concretos
    "nota_sala"               → observación general de sala sin nada concreto medible
    "avance_ciclo"            → cambio de estado del ciclo de un lote
    "tarea"                   → tarea futura (solo admin/supervisor)

    TAREAS FÍSICAS VÁLIDAS (array "tareas_realizadas"):
    riego | nutricion | poda | defoliacion | scrog_lst | revision_plagas | limpieza_sala | ajuste_luz

    ═══════════════════════════════════════════
    ESTRUCTURA JSON DE RESPUESTA
    ═══════════════════════════════════════════

    Devolvé SOLO el JSON sin backticks. El "resumen" puede incluir tu interpretación experta.

    {
      "resumen": "lo que entendiste + observación experta si corresponde",
      "acciones": [
        {
          "tipo": "registro_ambiental",
          "lote_codigo": "L-26-003",
          "datos": {
            "tareas_realizadas": ["riego", "nutricion"],
            "fertilizacion": true,
            "notas_fertilizacion": "base A + base B + bloom",
            "temperatura": 24.5, "humedad": 60, "ph": 6.2, "ec": 1.8,
            "co2": 900, "ppfd": 600, "horas_luz": 18,
            "temperatura_sustrato": 22, "ph_runoff": 6.4,
            "estado_general": "bueno", "plagas_observadas": "ninguna",
            "observaciones": "texto libre"
          }
        },
        {
          "tipo": "registro_ambiental_sala",
          "datos": { "tareas_realizadas": ["riego"], "fertilizacion": false, "temperatura": 24.5, "humedad": 60 }
        },
        {
          "tipo": "registro_planta",
          "planta_nombre": "L-26-003-P001",
          "datos": {
            "estado_salud": "regular", "color_hojas": "amarillo",
            "plagas": "leve", "deficiencias": "posible déficit de nitrógeno",
            "altura_cm": 45, "num_colas": 4, "notas": "texto"
          }
        },
        { "tipo": "nota_lote", "lote_codigo": "L-26-003", "datos": { "contenido": "texto" } },
        { "tipo": "nota_sala", "datos": { "contenido": "texto" } },
        { "tipo": "avance_ciclo", "lote_codigo": "L-26-003", "datos": { "estado_nuevo": "floracion", "descripcion": "motivo" } },
        { "tipo": "tarea", "datos": { "titulo": "Revisión plagas", "descripcion": "...", "prioridad": "alta", "sala_nombre": "Sala A", "dias_desde_hoy": 3 } }
      ]
    }

    ENUMS VÁLIDOS:
    estado_general / estado_salud: excelente | bueno | regular | malo | critico
    color_hojas:   verde_oscuro | verde_claro | amarillo | marron
    plagas:        ninguna | leve | moderada | severa
    prioridad:     baja | normal | media | alta | urgente
    estado_nuevo:  semilla | vegetativo | floracion | cosecha | curado | finalizado
  PROMPT

  LIMITE_LLAMADAS_POR_HORA = 20

  # POST /asistente/parsear
  def parsear
    return render json: { error: 'El registro por voz no está disponible para este club.' }, status: :forbidden unless current_user.club.feature?(:ia_voz)

    texto    = params[:texto].to_s.strip
    contexto = params[:contexto]

    return render json: { error: 'Texto vacío' }, status: :unprocessable_entity if texto.blank?
    return render json: { error: 'Límite de uso alcanzado. Volvé en unos minutos.' }, status: :too_many_requests if rate_limited?

    es_cultivador  = current_user.cultivador?
    sesion         = ConversacionAsistente.de_hoy(current_user)
    prompt_sistema = construir_prompt(contexto, es_cultivador) + sesion.historial_para_prompt
    resultado      = llamar_claude(texto, prompt_sistema)

    if resultado[:error]
      render json: { error: resultado[:error] }, status: :unprocessable_entity
    else
      if es_cultivador && resultado['acciones']
        resultado['acciones'] = resultado['acciones'].reject { |a| (a['tipo'] || a[:tipo]) == 'tarea' }
      end
      sesion.agregar_intercambio(texto, resultado['resumen'].to_s) rescue nil
      render json: resultado
    end
  end

  # POST /asistente/consultar
  def consultar
    return render json: { error: 'El registro por voz no está disponible para este club.' }, status: :forbidden unless current_user.club.feature?(:ia_voz)

    texto    = params[:texto].to_s.strip
    contexto = params[:contexto]

    return render json: { error: 'Texto vacío' }, status: :unprocessable_entity if texto.blank?
    return render json: { error: 'Límite de uso alcanzado. Volvé en unos minutos.' }, status: :too_many_requests if rate_limited?

    sesion  = ConversacionAsistente.de_hoy(current_user)
    prompt  = construir_prompt_consulta(contexto) + sesion.historial_para_prompt
    result  = llamar_claude_libre(texto, prompt)

    if result[:error]
      render json: { error: result[:error] }, status: :unprocessable_entity
    else
      sesion.agregar_intercambio(texto, result[:texto].truncate(150)) rescue nil
      render json: { respuesta: result[:texto] }
    end
  end

  # POST /asistente/analizar_lote
  def analizar_lote
    return render json: { error: 'El análisis de IA no está disponible para este club.' }, status: :forbidden unless current_user.club.feature?(:ia_analisis)
    return render json: { error: 'Límite de uso alcanzado. Volvé en unos minutos.' }, status: :too_many_requests if rate_limited?

    lote = current_user.club.lotes.find_by(id: params[:lote_id])
    return render json: { error: 'Lote no encontrado' }, status: :not_found unless lote

    reciente = lote.analisis_ia.where('created_at > ?', 4.hours.ago).order(created_at: :desc).first
    if reciente
      return render json: serializar_analisis(reciente).merge(
        cached:         true,
        cooldown_hasta: (reciente.created_at + 4.hours).iso8601
      )
    end

    resultado = AnalisisLoteService.new(lote, current_user).analizar!

    if resultado[:error]
      render json: { error: resultado[:error] }, status: :unprocessable_entity
    else
      a = resultado[:analisis_obj] || lote.analisis_ia.order(created_at: :desc).first
      render json: serializar_analisis(a).merge(
        cached:         false,
        cooldown_hasta: (a.created_at + 4.hours).iso8601
      )
    end
  end

  # GET /asistente/historial_analisis?lote_id=X
  def historial_analisis
    lote = current_user.club.lotes.find_by(id: params[:lote_id])
    return render json: { error: 'Lote no encontrado' }, status: :not_found unless lote

    analisis = lote.analisis_ia.order(created_at: :desc).limit(3)
    reciente = analisis.first
    cooldown_hasta = reciente ? (reciente.created_at + 4.hours).iso8601 : nil
    render json: {
      analisis:       analisis.map { |a| serializar_analisis(a) },
      cooldown_hasta: cooldown_hasta
    }
  end

  # POST /asistente/ejecutar
  def ejecutar
    return render json: { error: 'El registro por voz no está disponible para este club.' }, status: :forbidden unless current_user.club.feature?(:ia_voz)

    acciones = params[:acciones] || []
    contexto = params[:contexto]
    club     = current_user.club

    resultados = []
    errores    = []

    acciones.each do |accion|
      tipo  = accion[:tipo]  || accion['tipo']
      datos = (accion[:datos] || accion['datos'] || {}).to_unsafe_h rescue {}

      if tipo == 'tarea' && current_user.cultivador?
        errores << { tipo: tipo, error: 'Los cultivadores no pueden crear tareas' }
        next
      end

      accion_e = enriquecer_con_contexto(accion, contexto, club)

      resultado = case tipo
                  when 'registro_ambiental'      then ejecutar_registro_ambiental(accion_e, datos, club)
                  when 'registro_ambiental_sala' then ejecutar_registro_ambiental_sala(datos, club, contexto)
                  when 'registro_planta'         then ejecutar_registro_planta(accion_e, datos, club)
                  when 'tarea'                   then ejecutar_tarea(accion_e, datos, club, contexto)
                  when 'nota_sala'               then ejecutar_nota_sala(datos, club, contexto)
                  when 'nota_lote'               then ejecutar_nota_lote(accion_e, datos, club, contexto)
                  when 'avance_ciclo'            then ejecutar_avance_ciclo(accion_e, datos, club, contexto)
                  else { ok: false, error: "Tipo desconocido: #{tipo}" }
                  end

      if resultado[:ok]
        resultados << { tipo: tipo, mensaje: resultado[:mensaje] }
      else
        errores << { tipo: tipo, error: resultado[:error] }
      end
    end

    render json: {
      ejecutadas:      resultados.count,
      errores:         errores.count,
      resultados:      resultados,
      errores_detalle: errores
    }
  rescue StandardError => e
    Rails.logger.error "AsistenteController#ejecutar error: #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    render json: { error: "Error interno al ejecutar acciones: #{e.message}" }, status: :internal_server_error
  end

  private

  def cerrar_tareas_por_registro(datos, lote: nil, sala: nil)
    Tarea.cerrar_por_registro!(
      tareas_realizadas: Array(datos['tareas_realizadas']),
      usuario:           current_user,
      es_privilegiado:   current_user.admin? || current_user.supervisor?,
      lote:              lote,
      sala:              sala
    )
  rescue => e
    Rails.logger.warn "Auto-close tareas failed: #{e.message}"
    []
  end

  def serializar_analisis(a)
    { id: a.id, contenido: a.contenido, tokens_usados: a.tokens_usados, created_at: a.created_at }
  end

  def rate_limited?
    limite = current_user.club.ia_limite_efectivo
    key    = "asistente:club:#{current_user.club_id}:#{Time.current.strftime('%Y%m%d%H')}"
    redis  = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
    count  = redis.incr(key)
    redis.expire(key, 3600) if count == 1
    count > limite
  rescue
    false
  end

  def construir_prompt(contexto, es_cultivador)
    PROMPT_BASE.dup + permisos_rol(es_cultivador) + contexto_rico(contexto)
  end

  def construir_prompt_consulta(contexto)
    base = <<~PROMPT
      Sos un agrónomo especialista en cannabis medicinal. Respondés preguntas del equipo de cultivo
      de forma clara, directa y útil. Podés analizar datos, identificar tendencias, y dar recomendaciones.
      Respondés en español. Usá markdown si mejora la claridad. No generes JSON.
    PROMPT
    base + permisos_rol(current_user.cultivador?) + contexto_rico(contexto)
  end

  def permisos_rol(es_cultivador)
    if es_cultivador
      "\nROL: Este usuario es CULTIVADOR.\n" \
      "- NO generar acciones de tipo 'tarea'.\n" \
      "- Si menciona avanzar ciclo → nota_lote con 'Sugerencia: [lo que dijo]', no avance_ciclo.\n"
    else
      "\nROL: Este usuario es ADMIN/SUPERVISOR con permisos completos.\n" \
      "- Puede generar avance_ciclo cuando el cultivador lo mencione explícitamente.\n"
    end
  end

  def contexto_rico(contexto)
    return '' unless contexto.present?
    tipo = contexto[:tipo] || contexto['tipo']
    case tipo
    when 'planta' then ctx_planta(contexto)
    when 'lote'   then ctx_lote(contexto)
    when 'sala'   then ctx_sala(contexto)
    else ''
    end
  end

  def ctx_planta(contexto)
    planta = Plant.joins(:lote)
                  .where(lotes: { club_id: current_user.club_id })
                  .find_by(id: contexto[:planta_id] || contexto['planta_id'])
    return '' unless planta

    lote = planta.lote
    cepa = lote.genetica&.nombre || lote.strain || 'desconocida'

    ctx  = "\n═══ PLANTA: #{planta.nombre} ═══\n"
    ctx += "Cepa: #{cepa} | Estadío del lote: #{lote.estado} | Sala: #{lote.sala&.nombre || '—'}\n"
    ctx += "Semana #{semanas_desde(lote.start_date)} desde inicio del lote\n" if lote.start_date
    ctx += "\n"

    ctx += "ESTADO ACTUAL (no incluir estos campos si el cultivador no los menciona):\n"
    ctx += "  Altura: #{planta.altura_actual ? "#{planta.altura_actual} cm" : 'no registrada'}\n"
    ctx += "  Copas: #{planta.num_colas || 'no registrado'}\n"
    ctx += "  Salud: #{planta.estado_salud || 'no evaluada'}\n"
    ctx += "  Hojas: #{planta.color_hojas || 'no evaluado'}\n"
    ctx += "  Maceta: #{lote.tamanio_maceta ? "#{lote.tamanio_maceta}L" : 'desconocida'}"
    ctx += " | Sustrato: #{lote.sustrato_especifico}" if lote.sustrato_especifico.present?
    ctx += "\n\n"

    acts = planta.activities.order(occurred_at: :desc).limit(6)
    if acts.any?
      ctx += "ÚLTIMAS ACTIVIDADES:\n"
      acts.each do |a|
        f = a.occurred_at.strftime('%d/%m %H:%M')
        if a.activity_type == 'registro_planta' && a.metadata.present?
          m = a.metadata
          p = [].tap do |arr|
            arr << "#{m['altura_cm']}cm"         if m['altura_cm']
            arr << "#{m['num_colas']} copas"      if m['num_colas']
            arr << "salud #{m['estado_salud']}"   if m['estado_salud']
            arr << "plagas #{m['plagas']}"        if m['plagas'] && m['plagas'] != 'ninguna'
            arr << m['deficiencias']              if m['deficiencias'].present?
          end
          ctx += "  [#{f}] observación planta: #{p.join(' | ')}\n"
        else
          desc = a.description.present? ? " — #{a.description.truncate(60)}" : ''
          ctx += "  [#{f}] #{a.activity_type}#{desc}\n"
        end
      end
      ctx += "\n"
    end

    ultimo = lote.registros_ambientales.order(registrado_en: :desc).first
    if ultimo
      f = ultimo.registrado_en.strftime('%d/%m %H:%M')
      p = fmt_ambiental(ultimo)
      ctx += "ÚLTIMO REGISTRO AMBIENTAL DEL LOTE [#{f}]: #{p}\n"
      ctx += "  Tareas: #{ultimo.tareas_realizadas.join(', ')}\n" if ultimo.tareas_realizadas&.any?
      ctx += "\n"
    end

    ctx += "INSTRUCCIONES ESTRUCTURALES:\n"
    ctx += "  - planta_nombre = '#{planta.nombre}'\n"
    ctx += "  - Si el cultivador menciona actividades físicas además de observar la planta\n"
    ctx += "    → generar también registro_ambiental para el lote '#{lote.codigo}'.\n"
    ctx += "═════════════════════════════════════\n"
    ctx
  end

  def ctx_lote(contexto)
    lote = current_user.club.lotes.find_by(id: contexto[:lote_id] || contexto['lote_id'])
    return '' unless lote

    cepa = lote.genetica&.nombre || lote.strain || 'desconocida'

    ctx  = "\n═══ LOTE: #{lote.codigo} ═══\n"
    ctx += "Cepa: #{cepa} | Estadío: #{lote.estado} | Sala: #{lote.sala&.nombre || '—'}\n"
    ctx += "Plantas: #{lote.plants_count || 0}"
    ctx += " | Semana #{semanas_desde(lote.start_date)} desde inicio" if lote.start_date
    ctx += " | Floración estimada: #{lote.semanas_floracion} semanas" if lote.semanas_floracion
    ctx += "\n"
    ctx += "Maceta: #{lote.tamanio_maceta}L" if lote.tamanio_maceta
    ctx += " | Sustrato: #{lote.sustrato_especifico}" if lote.sustrato_especifico.present?
    ctx += " | Fotoperiodo: #{lote.fotoperiodo}" if lote.fotoperiodo.present?
    ctx += "\n\n"

    regs = lote.registros_ambientales.order(registrado_en: :desc).limit(5)
    if regs.any?
      ctx += "ÚLTIMOS REGISTROS AMBIENTALES:\n"
      regs.each do |r|
        f = r.registrado_en.strftime('%d/%m %H:%M')
        p = fmt_ambiental(r)
        tareas = r.tareas_realizadas&.any? ? " | tareas: #{r.tareas_realizadas.join(', ')}" : ''
        ctx += "  [#{f}] #{p}#{tareas}\n"
      end
      ctx += "\n"
    end

    tareas = current_user.club.tareas.where(lote_id: lote.id).activas.order(fecha_programada: :asc).limit(5)
    if tareas.any?
      ctx += "TAREAS ACTIVAS DEL LOTE:\n"
      tareas.each do |t|
        fecha = t.fecha_programada ? " (#{t.fecha_programada.strftime('%d/%m')})" : ''
        asig  = t.asignada_a ? " → #{t.asignada_a.nombre_completo}" : ' → sin asignar'
        ctx += "  [#{t.tipo}] #{t.titulo}#{fecha}#{asig}\n"
      end
      ctx += "\n"
    end

    ctx += "INSTRUCCIONES ESTRUCTURALES:\n"
    ctx += "  - lote_codigo = '#{lote.codigo}'\n"
    ctx += "  - Usar registro_ambiental o nota_lote, NO nota_sala.\n"
    ctx += "═════════════════════════════════════\n"
    ctx
  end

  def ctx_sala(contexto)
    sala = current_user.club.salas.find_by(id: contexto[:sala_id] || contexto['sala_id'])
    return '' unless sala

    lotes = sala.lotes.where.not(estado: 'finalizado').includes(:genetica)

    ctx  = "\n═══ SALA: #{sala.nombre} ═══\n"
    ctx += "Lotes activos: #{lotes.count}\n\n"

    if lotes.any?
      ctx += "ESTADO POR LOTE:\n"
      lotes.each do |l|
        cepa  = l.genetica&.nombre || l.strain || '—'
        ctx  += "  #{l.codigo} | #{cepa} | #{l.estado} | #{l.plants_count || 0} plantas\n"
        ultimo = l.registros_ambientales.order(registrado_en: :desc).first
        if ultimo
          hace = distancia_temporal(ultimo.registrado_en)
          ctx += "    Último reg (#{hace}): #{fmt_ambiental(ultimo)}\n"
        end
      end
      ctx += "\n"
    end

    ctx += "INSTRUCCIONES ESTRUCTURALES:\n"
    ctx += "  - Métricas o actividades sin nombrar lote → registro_ambiental_sala (aplica a todos).\n"
    ctx += "  - Lote nombrado explícitamente → registro_ambiental solo para ese lote.\n"
    ctx += "  - Observación general sin datos concretos → nota_sala.\n"
    ctx += "═════════════════════════════════════\n"
    ctx
  end

  def fmt_ambiental(r)
    [
      (r.temperatura ? "#{r.temperatura}°C"      : nil),
      (r.humedad     ? "HR #{r.humedad}%"         : nil),
      (r.ph          ? "pH #{r.ph}"               : nil),
      (r.ec          ? "EC #{r.ec}"               : nil),
      (r.co2         ? "CO2 #{r.co2}ppm"          : nil),
    ].compact.join(' | ').presence || 'sin métricas'
  end

  def semanas_desde(fecha)
    return nil unless fecha
    ((Date.current - fecha) / 7).floor
  end

  def distancia_temporal(dt)
    return '—' unless dt
    diff_h = ((Time.current - dt) / 3600).round
    return 'menos de 1h' if diff_h < 1
    return "hace #{diff_h}h"  if diff_h < 24
    "hace #{(diff_h / 24).round}d"
  end

  def enriquecer_con_contexto(accion, contexto, club)
    return accion unless contexto.present?

    accion = accion.to_unsafe_h rescue accion.to_h
    accion = accion.with_indifferent_access

    if accion[:lote_codigo].blank? && (contexto[:lote_id] || contexto['lote_id']).present?
      lote = club.lotes.find_by(id: contexto[:lote_id] || contexto['lote_id'])
      accion[:lote_codigo] = lote.codigo if lote
    end

    if accion[:planta_nombre].blank? && (contexto[:planta_id] || contexto['planta_id']).present?
      planta = Plant.joins(:lote).where(lotes: { club_id: club.id }).find_by(id: contexto[:planta_id] || contexto['planta_id'])
      accion[:planta_nombre] = planta.nombre if planta
    end

    accion
  end

  def llamar_claude_libre(texto, prompt_sistema)
    api_key = ENV['ANTHROPIC_API_KEY']
    return { error: 'API key de IA no configurada' } if api_key.blank?

    uri  = URI('https://api.anthropic.com/v1/messages')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.read_timeout = 45

    request = Net::HTTP::Post.new(uri)
    request['Content-Type']      = 'application/json'
    request['x-api-key']         = api_key
    request['anthropic-version'] = '2023-06-01'
    request.body = {
      model:      'claude-sonnet-4-6',
      max_tokens: 1000,
      system:     prompt_sistema,
      messages:   [{ role: 'user', content: texto }]
    }.to_json

    response = http.request(request)
    body     = JSON.parse(response.body)
    return { error: "IA: #{body.dig('error', 'message')}" } if response.code.to_i != 200

    { texto: body.dig('content', 0, 'text').to_s.strip }
  rescue => e
    { error: e.message }
  end

  def llamar_claude(texto, prompt_sistema)
    api_key = ENV['ANTHROPIC_API_KEY']
    return { error: 'API key de IA no configurada' } if api_key.blank?

    uri  = URI('https://api.anthropic.com/v1/messages')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri)
    request['Content-Type']      = 'application/json'
    request['x-api-key']         = api_key
    request['anthropic-version'] = '2023-06-01'

    request.body = {
      model:      'claude-sonnet-4-6',
      max_tokens: 1000,
      system:     prompt_sistema,
      messages:   [{ role: 'user', content: "Reporte del cultivador: \"#{texto}\"" }]
    }.to_json

    response = http.request(request)
    body     = JSON.parse(response.body)

    if response.code.to_i != 200
      return { error: "Error de IA: #{body['error']&.dig('message') || response.code}" }
    end

    content = body.dig('content', 0, 'text').to_s.strip
    content = content.gsub(/```json\n?/, '').gsub(/```/, '').strip

    begin
      JSON.parse(content, symbolize_names: false)
    rescue JSON::ParserError
      match = content.match(/\{[\s\S]*\}/)
      match ? JSON.parse(match[0]) : { error: 'No se pudo parsear la respuesta de IA' }
    end
  rescue => e
    Rails.logger.error "AsistenteController#llamar_claude error: #{e.message}"
    { error: 'Error de conexión con IA' }
  end

  def ejecutar_registro_ambiental(accion, datos, club)
    lote_codigo = accion['lote_codigo'] || accion[:lote_codigo]
    lote = club.lotes.find_by(codigo: lote_codigo) if lote_codigo.present?
    return { ok: false, error: "Lote '#{lote_codigo}' no encontrado" } unless lote

    campos = {
      ph:                   datos['ph'],
      ec:                   datos['ec'],
      temperatura:          datos['temperatura'],
      humedad:              datos['humedad'],
      co2:                  datos['co2'],
      ppfd:                 datos['ppfd'],
      horas_luz:            datos['horas_luz'],
      temperatura_sustrato: datos['temperatura_sustrato'],
      ph_runoff:            datos['ph_runoff'],
      tareas_realizadas:    Array(datos['tareas_realizadas']),
      fertilizacion:        datos['fertilizacion'] || false,
      notas_fertilizacion:  datos['notas_fertilizacion'],
      estado_general:       datos['estado_general'],
      plagas_observadas:    datos['plagas_observadas'],
      observaciones:        datos['observaciones'],
      fuente:               'asistente_voz',
      user:                 current_user,
      club:                 club,
      registrado_en:        Time.current
    }.compact

    registro = lote.registros_ambientales.build(campos)
    if registro.save
      tareas_cerradas = cerrar_tareas_por_registro(datos, lote: lote)
      msg = "Registro ambiental guardado en #{lote.codigo}"
      msg += " · #{tareas_cerradas.size} tarea#{'s' if tareas_cerradas.size != 1} completada#{'s' if tareas_cerradas.size != 1}: #{tareas_cerradas.join(', ')}" if tareas_cerradas.any?
      { ok: true, mensaje: msg }
    else
      { ok: false, error: registro.errors.full_messages.join(', ') }
    end
  end

  def ejecutar_registro_ambiental_sala(datos, club, contexto)
    sala_id = contexto&.dig('sala_id') || contexto&.dig(:sala_id)
    sala    = club.salas.find_by(id: sala_id) if sala_id.present?
    return { ok: false, error: 'Sala no encontrada en el contexto' } unless sala

    lotes = sala.lotes.where.not(estado: 'finalizado')
    return { ok: false, error: "No hay lotes activos en #{sala.nombre}" } if lotes.empty?

    campos_base = {
      ph:                   datos['ph'],
      ec:                   datos['ec'],
      temperatura:          datos['temperatura'],
      humedad:              datos['humedad'],
      co2:                  datos['co2'],
      ppfd:                 datos['ppfd'],
      horas_luz:            datos['horas_luz'],
      temperatura_sustrato: datos['temperatura_sustrato'],
      ph_runoff:            datos['ph_runoff'],
      tareas_realizadas:    Array(datos['tareas_realizadas']),
      fertilizacion:        datos['fertilizacion'] || false,
      notas_fertilizacion:  datos['notas_fertilizacion'],
      estado_general:       datos['estado_general'],
      plagas_observadas:    datos['plagas_observadas'],
      observaciones:        datos['observaciones'],
      fuente:               'asistente_voz',
      user:                 current_user,
      club:                 club,
      registrado_en:        Time.current,
    }.compact

    creados      = 0
    fallidos     = []
    lotes.each do |lote|
      r = lote.registros_ambientales.build(campos_base)
      r.save ? creados += 1 : fallidos << lote.codigo
    end

    if creados > 0
      tareas_cerradas = cerrar_tareas_por_registro(datos, sala: sala)
      msg = "Registro ambiental guardado en #{creados} lote#{'s' if creados != 1} de #{sala.nombre}"
      msg += " (falló: #{fallidos.join(', ')})" if fallidos.any?
      msg += " · #{tareas_cerradas.size} tarea#{'s' if tareas_cerradas.size != 1} completada#{'s' if tareas_cerradas.size != 1}: #{tareas_cerradas.join(', ')}" if tareas_cerradas.any?
      { ok: true, mensaje: msg }
    else
      { ok: false, error: "No se pudo guardar en ningún lote de #{sala.nombre}" }
    end
  end

  def ejecutar_registro_planta(accion, datos, club)
    planta_nombre = accion['planta_nombre'] || accion[:planta_nombre]
    planta = Plant.joins(:lote)
                  .where(lotes: { club_id: club.id })
                  .find_by(nombre: planta_nombre) if planta_nombre.present?
    return { ok: false, error: "Planta '#{planta_nombre}' no encontrada" } unless planta

    activity = planta.activities.build(
      activity_type: 'registro_planta',
      description:   datos['notas'],
      metadata: {
        estado_salud:  datos['estado_salud'],
        color_hojas:   datos['color_hojas'],
        plagas:        datos['plagas'],
        deficiencias:  datos['deficiencias'],
        altura_cm:     datos['altura_cm'],
        num_colas:     datos['num_colas'],
      }.compact,
      user:        current_user,
      occurred_at: Time.current
    )

    if activity.save
      planta.update_columns(
        estado_salud:  datos['estado_salud']  || planta.estado_salud,
        altura_actual: datos['altura_cm']     || planta.altura_actual,
        color_hojas:   datos['color_hojas']   || planta.color_hojas,
        num_colas:     datos['num_colas']     || planta.num_colas
      ) rescue nil
      { ok: true, mensaje: "Observación registrada en #{planta.nombre}" }
    else
      { ok: false, error: activity.errors.full_messages.join(', ') }
    end
  end

  def ejecutar_tarea(accion, datos, club, contexto = nil)
    sala_nombre = datos['sala_nombre']
    sala = club.salas.find_by('LOWER(nombre) LIKE ?', "%#{sala_nombre&.downcase}%") if sala_nombre.present?

    if sala.nil? && (contexto&.dig('sala_id') || contexto&.dig(:sala_id)).present?
      sala = club.salas.find_by(id: contexto['sala_id'] || contexto[:sala_id])
    end

    lote_id = contexto&.dig('lote_id') || contexto&.dig(:lote_id)
    lote    = club.lotes.find_by(id: lote_id) if lote_id.present?
    lote  ||= club.lotes.find_by(codigo: datos['lote_codigo']) if datos['lote_codigo'].present?

    dias  = (datos['dias_desde_hoy'] || 7).to_i
    fecha = dias.days.from_now.to_date

    tarea = club.tareas.build(
      titulo:           datos['titulo'],
      descripcion:      datos['descripcion'],
      prioridad:        datos['prioridad'] || 'media',
      estado:           'pendiente',
      fecha_programada: fecha,
      sala_id:          sala&.id,
      lote_id:          lote&.id,
      creada_por:       current_user
    )

    if tarea.save
      { ok: true, mensaje: "Tarea '#{tarea.titulo}' creada para el #{fecha.strftime('%d/%m/%Y')}" }
    else
      { ok: false, error: tarea.errors.full_messages.join(', ') }
    end
  end

  def ejecutar_nota_sala(datos, club, contexto)
    sala_id = contexto&.dig('sala_id') || contexto&.dig(:sala_id)
    sala    = club.salas.find_by(id: sala_id) if sala_id.present?
    return { ok: false, error: 'Sala no encontrada en el contexto' } unless sala

    contenido = datos['contenido'].to_s.strip
    return { ok: false, error: 'Nota vacía' } if contenido.blank?

    nota = sala.notas.build(contenido: contenido, fuente: 'asistente_voz', club: club, user: current_user)
    nota.save ? { ok: true, mensaje: "Nota guardada en #{sala.nombre}" } : { ok: false, error: nota.errors.full_messages.join(', ') }
  end

  def ejecutar_nota_lote(accion, datos, club, contexto)
    lote_codigo = accion['lote_codigo'] || accion[:lote_codigo]
    lote = club.lotes.find_by(codigo: lote_codigo) if lote_codigo.present?

    unless lote
      lote_id = contexto&.dig('lote_id') || contexto&.dig(:lote_id)
      lote    = club.lotes.find_by(id: lote_id) if lote_id.present?
    end

    return { ok: false, error: 'Lote no encontrado' } unless lote

    contenido = (datos['contenido'] || datos['observaciones'] || datos['notas']).to_s.strip
    return { ok: false, error: 'Nota vacía' } if contenido.blank?

    nota = lote.notas.build(contenido: contenido, fuente: 'asistente_voz', club: club, user: current_user)
    nota.save ? { ok: true, mensaje: "Nota guardada en #{lote.codigo}" } : { ok: false, error: nota.errors.full_messages.join(', ') }
  end

  def ejecutar_avance_ciclo(accion, datos, club, contexto)
    lote_codigo = accion['lote_codigo'] || accion[:lote_codigo]
    lote = club.lotes.find_by(codigo: lote_codigo) if lote_codigo.present?
    unless lote
      lote_id = contexto&.dig('lote_id') || contexto&.dig(:lote_id)
      lote = club.lotes.find_by(id: lote_id) if lote_id.present?
    end
    return { ok: false, error: 'Lote no encontrado' } unless lote

    estado_nuevo = datos['estado_nuevo']
    return { ok: false, error: 'Estado nuevo no especificado' } if estado_nuevo.blank?
    return { ok: false, error: "Estado inválido: #{estado_nuevo}" } unless Lote::ESTADOS.include?(estado_nuevo)

    estado_anterior = lote.estado
    if lote.update(estado: estado_nuevo)
      lote.lote_eventos.create!(
        tipo:             'cambio_estado',
        estado_anterior:  estado_anterior,
        estado_nuevo:     estado_nuevo,
        descripcion:      datos['descripcion'] || 'Avance de ciclo registrado por voz',
        user:             current_user,
        club:             club,
        registrado_en:    Time.current
      )
      { ok: true, mensaje: "Ciclo avanzado: #{estado_anterior} → #{estado_nuevo} en #{lote.codigo}" }
    else
      { ok: false, error: lote.errors.full_messages.join(', ') }
    end
  end


end