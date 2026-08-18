require 'net/http'
require 'json'

module Ia
  # El chatbot del admin: contesta con los datos de SU organización.
  #
  # Cómo funciona: se le ofrecen las consultas de `Consultas::Registro` como herramientas, el
  # modelo elige cuál necesita según la pregunta, la corremos nosotros contra la base con el club
  # ya fijado, y le devolvemos el resultado para que redacte.
  #
  # Por qué así y no pasándole un resumen precocido: un resumen sólo contesta lo que alguien
  # anticipó, y ante una pregunta que no está adentro el modelo inventa o se disculpa. Por qué
  # así y no dejándolo escribir SQL: es un modelo escribiendo consultas libres contra una base
  # multi-tenant con datos de salud.
  #
  # Lo que NO hace: tocar plata, stock, dispensaciones ni datos clínicos. Eso tiene su puerta,
  # con sus permisos y su trazabilidad, y un chatbot no puede ser una segunda entrada al mismo
  # lugar.
  class Chatbot
    MODELO      = Modelos::RAZONA
    MAX_VUELTAS = 3 # pregunta → consulta → respuesta. Más que eso es que se está enredando.

    SISTEMA = <<~PROMPT.freeze
      Sos el asistente de datos de una organización de cannabis medicinal en Cultivo Espacial, y
      hablás con quien la administra. Contestás sobre SU organización usando las herramientas.

      CÓMO CONTESTAR:
      - Usá una herramienta antes de afirmar cualquier dato. Nunca respondas de memoria.
      - Si la herramienta devuelve `suficiente: false`, decí que todavía no hay datos para eso y
        repetí textualmente qué falta. NO estimes, no completes con criterio propio, no uses
        conocimiento general de cultivo para rellenar. "Todavía no puedo saberlo" es una
        respuesta correcta y útil.
      - Cuando haya datos, decí SOBRE CUÁNTOS estás hablando ("sobre 4 lotes cosechados").
      - Si la herramienta trae `todavia_sin_datos`, nombralas: la persona tiene que saber que
        esas quedaron afuera y por qué.
      - Si un número viene con `estimado_segun`, decilo. No es lo mismo un pesado real que un
        objetivo que alguien cargó a ojo.

      TONO: directo y breve. Números concretos, sin adornos. Escribís en castellano rioplatense.

      LO QUE NO HACÉS:
      - No inventás datos que la herramienta no devolvió, ni siquiera aproximados.
      - No opinás sobre si cosechar: eso se decide mirando tricomas, no una fecha en la base.
      - No hablás de historia clínica, tratamientos ni datos médicos de pacientes.
    PROMPT

    def initialize(club, user)
      @club = club
      @user = user
    end

    # Cuántas vueltas de ida y vuelta se recuerdan.
    #
    # Corta a propósito: lo caro de una conversación es reenviar todo lo hablado en CADA vuelta,
    # y el hilo largo es justo la parte que nadie relee. Con esto alcanza para "¿y en la sala 3?",
    # que es el 90% de las repreguntas reales, sin que el crédito se vaya en historia muerta.
    MEMORIA = 4

    # Devuelve { texto:, consultas:, repreguntas: } o { error: }.
    #
    # `historial` son los turnos previos [{rol:, texto:}] que manda la pantalla. Se recortan acá y
    # no allá: el tope es una decisión de costo, no de interfaz.
    def preguntar(texto, historial: [])
      api_key = ENV['ANTHROPIC_API_KEY']
      return { error: 'IA no configurada' } if api_key.blank?

      mensajes = previos(historial) + [{ role: 'user', content: texto }]
      consultadas = []

      MAX_VUELTAS.times do
        cuerpo = llamar(api_key, mensajes)
        return { error: cuerpo[:error] } if cuerpo[:error]

        usos = cuerpo['content'].to_a.select { |b| b['type'] == 'tool_use' }
        if usos.empty?
          return {
            texto:       texto_de(cuerpo),
            consultas:   consultadas,
            repreguntas: Consultas::Registro.repreguntas(consultadas),
          }
        end

        mensajes << { role: 'assistant', content: cuerpo['content'] }
        mensajes << { role: 'user', content: usos.map { |u| resultado_de(u, consultadas) } }
      end

      # Se quedó dando vueltas entre herramientas: mejor decirlo que devolver algo a medias.
      { error: 'No pude armar la respuesta con los datos disponibles. Probá preguntándolo más acotado.' }
    end

    private

    attr_reader :club, :user

    # Sólo texto plano: los bloques de herramienta de vueltas anteriores no se reenvían. Sin eso,
    # cada repregunta arrastraría los resultados completos de todas las consultas previas y una
    # charla de cuatro turnos costaría varias veces lo que cuesta la primera.
    def previos(historial)
      Array(historial).last(MEMORIA).filter_map do |t|
        rol   = (t[:rol] || t['rol']).to_s
        texto = (t[:texto] || t['texto']).to_s.strip
        next if texto.blank? || !%w[user assistant].include?(rol)

        { role: rol, content: texto }
      end
    end

    def resultado_de(uso, consultadas)
      consultadas << uso['name']
      salida = Consultas::Registro.resolver(uso['name'], club) ||
               { suficiente: false, falta: 'esa consulta no existe' }

      { type: 'tool_result', tool_use_id: uso['id'], content: salida.to_json }
    end

    def texto_de(cuerpo)
      cuerpo['content'].to_a.select { |b| b['type'] == 'text' }.map { |b| b['text'] }.join("\n").strip
    end

    def llamar(api_key, mensajes)
      uri  = URI('https://api.anthropic.com/v1/messages')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = true
      http.read_timeout = 60

      req = Net::HTTP::Post.new(uri)
      req['Content-Type']      = 'application/json'
      req['x-api-key']         = api_key
      req['anthropic-version'] = '2023-06-01'
      req.body = {
        model:      MODELO,
        max_tokens: 1500,
        # El bloque fijo lleva `cache_control`: se repite en cada pregunta de cada admin.
        system:     [{ type: 'text', text: SISTEMA, cache_control: { type: 'ephemeral' } }],
        tools:      Consultas::Registro.herramientas,
        messages:   mensajes,
      }.to_json

      res  = http.request(req)
      body = JSON.parse(res.body)

      Uso.registrar(club: club, user: user, funcion: :asistente_consultar, modelo: MODELO,
                    tokens: Uso.tokens_de(body), ok: res.code.to_i == 200)

      return { error: body.dig('error', 'message') || 'Error de IA' } if res.code.to_i != 200

      body
    rescue StandardError => e
      Uso.registrar(club: club, user: user, funcion: :asistente_consultar, modelo: MODELO,
                    ok: false, error_clase: e.class.name)
      { error: e.message }
    end
  end
end
