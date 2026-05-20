class AnalisisLoteService
  require 'net/http'
  require 'json'

  def initialize(lote, usuario)
    @lote    = lote
    @usuario = usuario
    @club    = lote.club
  end

  def analizar!
    api_key = ENV['ANTHROPIC_API_KEY']
    return { error: 'API key de IA no configurada' } if api_key.blank?

    contexto = construir_contexto
    resultado = llamar_claude(api_key, contexto)
    return { error: resultado[:error] } if resultado[:error]

    analisis = AnalisisIa.create!(
      club:          @club,
      lote:          @lote,
      user:          @usuario,
      tipo:          'lote',
      contenido:     resultado[:texto],
      tokens_usados: resultado[:tokens]
    )

    { ok: true, analisis: serializar(analisis), analisis_obj: analisis }
  rescue => e
    Rails.logger.error "AnalisisLoteService error: #{e.message}"
    { error: e.message }
  end

  private

  def construir_contexto
    cepa = @lote.genetica&.nombre || @lote.strain || 'desconocida'

    ctx  = "LOTE: #{@lote.codigo} | Cepa: #{cepa} | Estado: #{@lote.estado}\n"
    ctx += "Semana #{semanas_desde(@lote.start_date)} desde inicio del lote\n" if @lote.start_date
    ctx += "Floración estimada: #{@lote.semanas_floracion} semanas\n"           if @lote.semanas_floracion
    ctx += "Maceta: #{@lote.tamanio_maceta}L"                                   if @lote.tamanio_maceta
    ctx += " | Sustrato: #{@lote.sustrato_especifico}"                          if @lote.sustrato_especifico.present?
    ctx += " | Fotoperiodo: #{@lote.fotoperiodo}"                               if @lote.fotoperiodo.present?
    ctx += "\n\n"

    regs = @lote.registros_ambientales.where('registrado_en > ?', 14.days.ago).order(:registrado_en)
    if regs.any?
      ctx += "HISTORIAL AMBIENTAL — ÚLTIMOS 14 DÍAS (#{regs.count} registros):\n"
      regs.each do |r|
        f    = r.registrado_en.strftime('%d/%m %H:%M')
        vals = [
          r.temperatura ? "#{r.temperatura}°C" : nil,
          r.humedad     ? "HR#{r.humedad}%"    : nil,
          r.ph          ? "pH#{r.ph}"          : nil,
          r.ec          ? "EC#{r.ec}"          : nil,
          r.co2         ? "CO₂#{r.co2}"        : nil,
        ].compact.join(' ')
        tareas = r.tareas_realizadas&.any? ? " [#{r.tareas_realizadas.join(', ')}]" : ''
        fert   = r.fertilizacion? ? " fertilizó: #{r.notas_fertilizacion}" : ''
        ctx += "  #{f}: #{vals.presence || '—'}#{tareas}#{fert}\n"
      end
      ctx += "\n"
    end

    plants = @lote.plants.order(:nombre).limit(6)
    if plants.any?
      ctx += "ESTADO DE PLANTAS (muestra de #{plants.count}):\n"
      plants.each do |p|
        ctx += "  #{p.nombre}: "
        parts = []
        parts << "#{p.altura_actual}cm" if p.altura_actual
        parts << "#{p.num_colas} copas" if p.num_colas
        parts << "salud=#{p.estado_salud}"     if p.estado_salud
        parts << "hojas=#{p.color_hojas}"      if p.color_hojas
        last_act = p.activities.order(occurred_at: :desc).first
        if last_act&.metadata.present?
          m = last_act.metadata
          parts << "plagas=#{m['plagas']}"      if m['plagas'].present? && m['plagas'] != 'ninguna'
          parts << m['deficiencias']             if m['deficiencias'].present?
        end
        ctx += parts.join(' | ') + "\n"
      end
      ctx += "\n"
    end

    alertas = @club.alertas_internas.where(lote: @lote).where(leida_at: nil).recientes.limit(5)
    if alertas.any?
      ctx += "ALERTAS ACTIVAS DEL LOTE:\n"
      alertas.each { |a| ctx += "  [#{a.severidad.upcase}] #{a.mensaje}\n" }
      ctx += "\n"
    end

    ctx
  end

  def llamar_claude(api_key, contexto)
    prompt = <<~PROMPT
      Sos un agrónomo especialista en cannabis medicinal. Analizás el historial de un lote de cultivo
      para dar un diagnóstico claro y recomendaciones accionables al equipo.

      #{contexto}

      Escribí un análisis en markdown con estas secciones:
      **Estado general**: diagnóstico del momento actual (2-3 oraciones)
      **Tendencias observadas**: qué viene cambiando en los datos ambientales y las plantas
      **Señales de atención**: anomalías, riesgos o situaciones que requieren acción
      **Recomendaciones**: 3-5 acciones concretas, ordenadas por prioridad

      Sé directo, específico y útil. Si los datos son insuficientes para una sección, decilo en una línea.
    PROMPT

    uri  = URI('https://api.anthropic.com/v1/messages')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.read_timeout = 60

    req = Net::HTTP::Post.new(uri)
    req['Content-Type']      = 'application/json'
    req['x-api-key']         = api_key
    req['anthropic-version'] = '2023-06-01'
    req.body = {
      model:      'claude-sonnet-4-6',
      max_tokens: 1500,
      messages:   [{ role: 'user', content: prompt }]
    }.to_json

    res  = http.request(req)
    body = JSON.parse(res.body)

    return { error: "IA: #{body.dig('error', 'message')}" } if res.code.to_i != 200

    {
      texto:  body.dig('content', 0, 'text').to_s.strip,
      tokens: body.dig('usage', 'output_tokens'),
    }
  rescue => e
    { error: e.message }
  end

  def serializar(a)
    { id: a.id, contenido: a.contenido, tokens_usados: a.tokens_usados, created_at: a.created_at }
  end

  def semanas_desde(fecha)
    return nil unless fecha
    ((Date.current - fecha) / 7).floor
  end
end
