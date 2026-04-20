class AsistenteController < ApplicationController
  before_action :authenticate_user!
  require 'net/http'
  require 'json'

  PROMPT_BASE = <<~PROMPT
    Sos un asistente inteligente para clubes de cannabis medicinal bajo el programa REPROCANN de Argentina.
    Tu función es analizar el reporte oral de un cultivador y extraer acciones estructuradas.

    El cultivador puede mencionar:
    - Riegos o fertilizaciones → acción tipo "registro_ambiental"
    - Observaciones sobre plantas → acción tipo "registro_planta"
    - Tareas a futuro → acción tipo "tarea"
    - Notas generales → acción tipo "nota_lote"

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
            "deficiencias": "déficit de nitrógeno en hojas bajas",
            "notas": "observación visual"
          }
        },
        {
          "tipo": "tarea",
          "datos": {
            "titulo": "Revisión de plagas en sala de floración",
            "descripcion": "El cultivador observó la necesidad de revisar plagas",
            "prioridad": "media",
            "sala_nombre": "Sala Floración",
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
    - Si el cultivador dice "todas las plantas" o no menciona planta específica → es registro_ambiental del lote
    - dias_desde_hoy: cuántos días desde hoy se programa la tarea
    - Incluí solo los campos que puedas inferir del texto
    - Nunca inventes datos que no están en el texto
  PROMPT

  # POST /asistente/parsear
  def parsear
    texto    = params[:texto].to_s.strip
    contexto = params[:contexto]

    return render json: { error: 'Texto vacío' }, status: :unprocessable_entity if texto.blank?

    prompt_sistema = construir_prompt(contexto)
    resultado      = llamar_claude(texto, prompt_sistema, contexto)

    if resultado[:error]
      render json: { error: resultado[:error] }, status: :unprocessable_entity
    else
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

      # Enriquecer con contexto implícito si el backend lo tiene
      accion_enriquecida = enriquecer_con_contexto(accion, contexto, club)

      resultado = case tipo
                  when 'registro_ambiental' then ejecutar_registro_ambiental(accion_enriquecida, datos, club)
                  when 'registro_planta'    then ejecutar_registro_planta(accion_enriquecida, datos, club)
                  when 'tarea'              then ejecutar_tarea(accion_enriquecida, datos, club, contexto)
                  when 'nota_lote'          then ejecutar_nota_lote(accion_enriquecida, datos, club)
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

  # Construye el prompt del sistema inyectando contexto real
  def construir_prompt(contexto)
    return PROMPT_BASE unless contexto.present?

    ctx_texto = "\n\n=== CONTEXTO ACTUAL DE LA VISTA ===\n"

    if contexto[:lote_id].present? || contexto['lote_id'].present?
      lote_id    = contexto[:lote_id] || contexto['lote_id']
      lote       = current_user.club.lotes.find_by(id: lote_id)
      if lote
        ctx_texto += "El cultivador está registrando en el lote: #{lote.codigo}\n"
        ctx_texto += "Sala: #{lote.sala&.nombre || 'no especificada'}\n"
        ctx_texto += "Estado del lote: #{lote.estado}\n"
        ctx_texto += "Plantas en este lote: #{lote.plants_count || 0}\n"
        ctx_texto += "\nIMPORTANTE: Usá '#{lote.codigo}' como lote_codigo en TODAS las acciones de tipo registro_ambiental y nota_lote.\n"
        ctx_texto += "No necesitás que el cultivador mencione el lote — ya está implícito.\n"
      end
    end

    if contexto[:planta_id].present? || contexto['planta_id'].present?
      planta_id = contexto[:planta_id] || contexto['planta_id']
      planta    = Plant.joins(:lote).where(lotes: { club_id: current_user.club.id }).find_by(id: planta_id)
      if planta
        ctx_texto += "El cultivador está registrando sobre la planta: #{planta.nombre}\n"
        ctx_texto += "\nIMPORTANTE: Usá '#{planta.nombre}' como planta_nombre en TODAS las acciones de tipo registro_planta.\n"
      end
    end

    if contexto[:sala_id].present? || contexto['sala_id'].present?
      sala_id = contexto[:sala_id] || contexto['sala_id']
      sala    = current_user.club.salas.find_by(id: sala_id)
      ctx_texto += "Sala actual: #{sala.nombre}\n" if sala
    end

    ctx_texto += "=================================\n"

    PROMPT_BASE + ctx_texto
  end

  # Enriquece la acción con datos del contexto cuando el campo está vacío
  def enriquecer_con_contexto(accion, contexto, club)
    return accion unless contexto.present?

    accion = accion.to_unsafe_h rescue accion.to_h
    accion = accion.with_indifferent_access

    # Si el lote_codigo no fue resuelto por Claude, usar el del contexto
    if accion[:lote_codigo].blank? && (contexto[:lote_id] || contexto['lote_id']).present?
      lote_id = contexto[:lote_id] || contexto['lote_id']
      lote    = club.lotes.find_by(id: lote_id)
      accion[:lote_codigo] = lote.codigo if lote
    end

    # Si la planta no fue resuelta, usar la del contexto
    if accion[:planta_nombre].blank? && (contexto[:planta_id] || contexto['planta_id']).present?
      planta_id = contexto[:planta_id] || contexto['planta_id']
      planta    = Plant.joins(:lote).where(lotes: { club_id: club.id }).find_by(id: planta_id)
      accion[:planta_nombre] = planta.nombre if planta
    end

    accion
  end

  def llamar_claude(texto, prompt_sistema, contexto = nil)
    api_key = ENV['ANTHROPIC_API_KEY']
    return { error: 'API key de IA no configurada' } if api_key.blank?

    uri  = URI('https://api.anthropic.com/v1/messages')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl    = true
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
    lote        = club.lotes.find_by(codigo: lote_codigo) if lote_codigo.present?

    return { ok: false, error: "Lote '#{lote_codigo}' no encontrado" } unless lote

    campos = {
      ph:                  datos['ph'],
      ec:                  datos['ec'],
      temperatura:         datos['temperatura'],
      humedad:             datos['humedad'],
      co2:                 datos['co2'],
      ppfd:                datos['ppfd'],
      horas_luz:           datos['horas_luz'],
      temperatura_sustrato: datos['temperatura_sustrato'],
      ph_runoff:           datos['ph_runoff'],
      fertilizacion:       datos['fertilizacion'] || false,
      notas_fertilizacion: datos['notas_fertilizacion'],
      estado_general:      datos['estado_general'],
      plagas_observadas:   datos['plagas_observadas'],
      observaciones:       datos['observaciones'],
      fuente:              'asistente_voz',
      user:                current_user,
      club:                club,
      registrado_en:       Time.current
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

    # Si no encontró sala por nombre, usar la del contexto
    if sala.nil? && (contexto&.dig('sala_id') || contexto&.dig(:sala_id)).present?
      sala_id = contexto['sala_id'] || contexto[:sala_id]
      sala = club.salas.find_by(id: sala_id)
    end

    # Lote: del contexto o del campo explícito
    lote_id = contexto&.dig('lote_id') || contexto&.dig(:lote_id)
    lote = club.lotes.find_by(id: lote_id) if lote_id.present?
    lote ||= club.lotes.find_by(codigo: datos['lote_codigo']) if datos['lote_codigo'].present?

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

  def ejecutar_nota_lote(accion, datos, club)
    lote_codigo = accion['lote_codigo'] || accion[:lote_codigo]
    lote        = club.lotes.find_by(codigo: lote_codigo) if lote_codigo.present?

    return { ok: false, error: "Lote '#{lote_codigo}' no encontrado" } unless lote

    registro = lote.registros_ambientales.build(
      observaciones: datos['observaciones'] || datos['notas'],
      fuente:        'asistente_voz',
      user:          current_user,
      club:          club,
      registrado_en: Time.current
    )

    if registro.save
      { ok: true, mensaje: "Nota guardada en #{lote.codigo}" }
    else
      { ok: false, error: registro.errors.full_messages.join(', ') }
    end
  end
end