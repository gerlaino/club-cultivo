class AsistenteController < ApplicationController
  before_action :authenticate_user!
  require 'net/http'
  require 'json'

  PROMPT_BASE = <<~PROMPT
    Sos un asistente inteligente para clubes de cannabis medicinal bajo el programa REPROCANN de Argentina.
    Tu función es analizar el reporte oral de un cultivador y extraer acciones estructuradas.

    Tipos de acciones posibles:
    - "registro_ambiental": riego, fertilización, métricas del lote (pH, EC, temperatura, etc.)
    - "registro_planta": observación de una planta específica o todas las plantas del lote
    - "nota_sala": nota general sobre la sala (actividad del día, observaciones generales)
    - "nota_lote": nota libre sobre un lote
    - "tarea": tarea a futuro (SOLO si el contexto lo permite — no para cultivadores)

    Devolvé SOLO un JSON con esta estructura exacta, sin texto adicional ni backticks:
    {
      "resumen": "descripción breve de lo que entendiste",
      "acciones": [
        {
          "tipo": "registro_ambiental",
          "lote_codigo": "USAR_CODIGO_DEL_CONTEXTO_SI_EXISTE",
          "datos": {
            "ph": 6.2,
            "ec": 1.4,
            "temperatura": 24.5,
            "humedad": 60,
            "fertilizacion": true,
            "notas_fertilizacion": "base A + base B + bloom, 2 pulsos",
            "estado_general": "bueno",
            "plagas_observadas": "ninguna",
            "observaciones": "riego completo"
          }
        },
        {
          "tipo": "registro_planta",
          "planta_nombre": "L-26-003-P001",
          "datos": {
            "estado_salud": "regular",
            "color_hojas": "amarillo",
            "plagas": "ninguna",
            "deficiencias": "deficit de nitrogeno en hojas bajas",
            "notas": "observacion visual"
          }
        },
        {
          "tipo": "nota_sala",
          "datos": {
            "contenido": "texto de la nota"
          }
        },
        {
          "tipo": "nota_lote",
          "lote_codigo": "L-26-003",
          "datos": {
            "contenido": "texto de la nota"
          }
        },
        {
          "tipo": "tarea",
          "datos": {
            "titulo": "Revision de plagas",
            "descripcion": "descripcion",
            "prioridad": "media",
            "sala_nombre": "Sala Floracion",
            "dias_desde_hoy": 7
          }
        }
      ]
    }

    Reglas:
    - estado_salud: excelente | bueno | regular | malo | critico
    - color_hojas: verde_oscuro | verde_claro | amarillo | marron
    - plagas: ninguna | leve | moderada | severa
    - estado_general: excelente | bueno | regular | malo | critico
    - plagas_observadas: ninguna | leve | moderada | severa
    - prioridad: baja | normal | media | alta | urgente
    - Si el cultivador dice "todas las plantas" o no menciona planta especifica => registro_ambiental del lote
    - Si estas en contexto de sala => usa nota_sala para observaciones generales
    - dias_desde_hoy: cuantos dias desde hoy se programa la tarea
    - Incluye solo los campos que puedas inferir del texto
    - Nunca inventes datos que no estan en el texto
  PROMPT

  # POST /asistente/parsear
  def parsear
    texto    = params[:texto].to_s.strip
    contexto = params[:contexto]

    return render json: { error: 'Texto vacío' }, status: :unprocessable_entity if texto.blank?

    es_cultivador  = current_user.cultivador?
    prompt_sistema = construir_prompt(contexto, es_cultivador)
    resultado      = llamar_claude(texto, prompt_sistema)

    if resultado[:error]
      render json: { error: resultado[:error] }, status: :unprocessable_entity
    else
      # Cultivador nunca crea tareas
      if es_cultivador && resultado['acciones']
        resultado['acciones'] = resultado['acciones'].reject { |a| (a['tipo'] || a[:tipo]) == 'tarea' }
      end
      render json: resultado
    end
  end

  # POST /asistente/ejecutar
  def ejecutar
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
                  when 'registro_ambiental' then ejecutar_registro_ambiental(accion_e, datos, club)
                  when 'registro_planta'    then ejecutar_registro_planta(accion_e, datos, club)
                  when 'tarea'              then ejecutar_tarea(accion_e, datos, club, contexto)
                  when 'nota_sala'          then ejecutar_nota_sala(datos, club, contexto)
                  when 'nota_lote'          then ejecutar_nota_lote(accion_e, datos, club, contexto)
                  when 'avance_ciclo'       then ejecutar_avance_ciclo(accion_e, datos, club, contexto)
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
  end

  private

  def construir_prompt(contexto, es_cultivador)
    prompt = PROMPT_BASE.dup

    if es_cultivador
      prompt += "\n\nIMPORTANTE: Este usuario es CULTIVADOR.\n"
      prompt += "- NO generes acciones de tipo 'tarea' bajo ninguna circunstancia.\n"
      prompt += "- Si el cultivador menciona 'avanzar ciclo', 'pasar a floración', 'cambiar estado' o similar, generá una nota_lote con contenido: 'Sugerencia del cultivador: [lo que dijo]'. No generes avance_ciclo.\n"
    else
      prompt += "\n\nEste usuario es ADMIN o AGRICULTOR y tiene permisos completos.\n"
      prompt += "- Puede generar acciones de tipo 'avance_ciclo'.\n"
      prompt += "- Si menciona 'avanzar ciclo', 'pasar a floración', 'cambiar a vegetativo', etc., generá:\n"
      prompt += "  { \"tipo\": \"avance_ciclo\", \"datos\": { \"estado_nuevo\": \"floracion\", \"descripcion\": \"motivo o descripción\" } }\n"
      prompt += "- estado_nuevo debe ser uno de: semilla | vegetativo | floracion | cosecha | curado | finalizado\n"
    end

    return prompt unless contexto.present?

    ctx      = "\n=== CONTEXTO ACTUAL ===\n"
    tipo_ctx = contexto[:tipo] || contexto['tipo']

    case tipo_ctx
    when 'lote'
      lote_id = contexto[:lote_id] || contexto['lote_id']
      lote    = current_user.club.lotes.find_by(id: lote_id)
      if lote
        ctx += "Lote: #{lote.codigo} | Sala: #{lote.sala&.nombre || 'no especificada'} | Estado: #{lote.estado} | Plantas: #{lote.plants_count || 0}\n"
        ctx += "USAR '#{lote.codigo}' como lote_codigo en registro_ambiental y nota_lote.\n"
        ctx += "Para observaciones generales usar registro_ambiental o nota_lote, NO nota_sala.\n"
      end
    when 'planta'
      planta_id = contexto[:planta_id] || contexto['planta_id']
      planta    = Plant.joins(:lote).where(lotes: { club_id: current_user.club.id }).find_by(id: planta_id)
      if planta
        ctx += "Planta: #{planta.nombre} | Lote: #{planta.lote&.codigo}\n"
        ctx += "USAR '#{planta.nombre}' como planta_nombre. Solo generar registro_planta.\n"
        ctx += "No generes registro_ambiental ni nota_sala para esta planta individual.\n"
      end
    when 'sala'
      sala_id = contexto[:sala_id] || contexto['sala_id']
      sala    = current_user.club.salas.find_by(id: sala_id)
      if sala
        lotes_codigos = sala.lotes.pluck(:codigo)
        ctx += "Sala: #{sala.nombre}\n"
        ctx += "Lotes en esta sala: #{lotes_codigos.join(', ')}\n" if lotes_codigos.any?
        ctx += "Para actividad general de la sala usar nota_sala.\n"
        ctx += "Si menciona un lote especifico, agregar registro_ambiental con ese lote_codigo.\n"
      end
    end

    ctx += "======================\n"
    prompt + ctx
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
      { ok: true, mensaje: "Registro ambiental guardado en #{lote.codigo}" }
    else
      { ok: false, error: registro.errors.full_messages.join(', ') }
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
        color_hojas:   datos['color_hojas']   || planta.color_hojas
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