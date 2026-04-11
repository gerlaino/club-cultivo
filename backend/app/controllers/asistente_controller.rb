class AsistenteController < ApplicationController
  before_action :authenticate_user!
  require 'net/http'
  require 'json'

  PROMPT_SISTEMA = <<~PROMPT
    Sos un asistente inteligente para clubes de cannabis medicinal bajo el programa REPROCANN de Argentina.
    Tu función es analizar el reporte oral de un cultivador y extraer acciones estructuradas.

    El cultivador puede mencionar:
    - Riegos o fertilizaciones en un lote → acción tipo "registro_ambiental"
    - Observaciones sobre una planta específica → acción tipo "registro_planta"
    - Tareas a futuro → acción tipo "tarea"
    - Notas generales sobre un lote → acción tipo "nota_lote"

    Devolvé SOLO un JSON con esta estructura exacta, sin texto adicional:
    {
      "resumen": "descripción breve de lo que entendiste",
      "acciones": [
        {
          "tipo": "registro_ambiental",
          "lote_codigo": "L-26-003",
          "datos": {
            "ph": 6.2,
            "ec": 1.4,
            "fertilizacion": true,
            "notas_fertilizacion": "solución nutritiva EC 1.4",
            "observaciones": "riego completo del lote"
          }
        },
        {
          "tipo": "registro_planta",
          "planta_nombre": "L-26-003-P012",
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

    Reglas importantes:
    - estado_salud debe ser uno de: excelente, bueno, regular, malo, critico
    - color_hojas debe ser uno de: verde_oscuro, verde_claro, amarillo, marron
    - plagas debe ser uno de: ninguna, leve, moderada, severa
    - prioridad debe ser uno de: baja, normal, media, alta, urgente
    - Si no podés identificar el lote o planta, igual incluí la acción con el campo en null
    - Si el cultivador dice "todas las plantas del lote X", es un registro_ambiental del lote
    - dias_desde_hoy es cuántos días desde hoy se programa la tarea (7 = próxima semana)
    - Incluí solo los campos que puedas inferir del texto
    - Nunca inventes datos que no están en el texto
  PROMPT

  # POST /asistente/parsear
  # Recibe: { texto: "..." }
  # Devuelve: { resumen: "...", acciones: [...] }
  def parsear
    texto = params[:texto].to_s.strip
    return render json: { error: 'Texto vacío' }, status: :unprocessable_entity if texto.blank?

    resultado = llamar_claude(texto)
    if resultado[:error]
      render json: { error: resultado[:error] }, status: :unprocessable_entity
    else
      render json: resultado
    end
  end

  # POST /asistente/ejecutar
  # Recibe: { acciones: [...] }
  # Devuelve: { ejecutadas: N, resultados: [...] }
  def ejecutar
    acciones   = params[:acciones] || []
    club       = current_user.club
    resultados = []
    errores    = []

    acciones.each do |accion|
      tipo = accion[:tipo] || accion['tipo']
      datos = (accion[:datos] || accion['datos'] || {}).to_unsafe_h rescue {}

      case tipo
      when 'registro_ambiental'
        resultado = ejecutar_registro_ambiental(accion, datos, club)
      when 'registro_planta'
        resultado = ejecutar_registro_planta(accion, datos, club)
      when 'tarea'
        resultado = ejecutar_tarea(accion, datos, club)
      when 'nota_lote'
        resultado = ejecutar_nota_lote(accion, datos, club)
      else
        resultado = { ok: false, error: "Tipo desconocido: #{tipo}" }
      end

      if resultado[:ok]
        resultados << { tipo: tipo, mensaje: resultado[:mensaje] }
      else
        errores << { tipo: tipo, error: resultado[:error] }
      end
    end

    render json: {
      ejecutadas: resultados.count,
      errores:    errores.count,
      resultados: resultados,
      errores_detalle: errores
    }
  end

  private

  def llamar_claude(texto)
    api_key = ENV['ANTHROPIC_API_KEY']
    return { error: 'API key de IA no configurada' } if api_key.blank?

    uri  = URI('https://api.anthropic.com/v1/messages')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri)
    request['Content-Type']      = 'application/json'
    request['x-api-key']         = api_key
    request['anthropic-version'] = '2023-06-01'

    request.body = {
      model:      'claude-sonnet-4-6',
      max_tokens: 1000,
      system:     PROMPT_SISTEMA,
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
      ph:                  datos['ph'],
      ec:                  datos['ec'],
      temperatura:         datos['temperatura'],
      humedad:             datos['humedad'],
      co2:                 datos['co2'],
      fertilizacion:       datos['fertilizacion'] || false,
      notas_fertilizacion: datos['notas_fertilizacion'],
      observaciones:       datos['observaciones'],
      estado_general:      datos['estado_general'],
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
        estado_salud: datos['estado_salud'] || planta.estado_salud,
        altura_actual: datos['altura_cm'] || planta.altura_actual,
        color_hojas: datos['color_hojas'] || planta.color_hojas
      ) rescue nil
      { ok: true, mensaje: "Observación registrada en #{planta.nombre}" }
    else
      { ok: false, error: activity.errors.full_messages.join(', ') }
    end
  end

  def ejecutar_tarea(accion, datos, club)
    sala_nombre = datos['sala_nombre']
    sala = club.salas.find_by('LOWER(nombre) LIKE ?', "%#{sala_nombre&.downcase}%") if sala_nombre.present?

    lote_codigo = datos['lote_codigo']
    lote = club.lotes.find_by(codigo: lote_codigo) if lote_codigo.present?

    dias = (datos['dias_desde_hoy'] || 7).to_i
    fecha = dias.days.from_now.to_date

    tarea = club.tareas.build(
      titulo:           datos['titulo'],
      descripcion:      datos['descripcion'],
      prioridad:        datos['prioridad'] || 'media',
      estado:           'pendiente',
      fecha_programada: fecha,
      sala_id:          sala&.id,
      lote_id:          lote&.id,
      creada_por:       current_user,
      )

    if tarea.save
      { ok: true, mensaje: "Tarea '#{tarea.titulo}' creada para el #{fecha.strftime('%d/%m/%Y')}" }
    else
      { ok: false, error: tarea.errors.full_messages.join(', ') }
    end
  end

  def ejecutar_nota_lote(accion, datos, club)
    lote_codigo = accion['lote_codigo'] || accion[:lote_codigo]
    lote = club.lotes.find_by(codigo: lote_codigo) if lote_codigo.present?
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