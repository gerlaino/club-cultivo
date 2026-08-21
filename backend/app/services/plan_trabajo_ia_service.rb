class PlanTrabajoIaService
  TIPOS_VALIDOS    = %w[riego poda medicion limpieza cosecha trasplante inspeccion otro].freeze
  PRIORIDADES_VALIDAS = %w[baja normal alta urgente].freeze
  MODELO              = Ia::Modelos::RAZONA

  def initialize(archivo, club)
    @archivo  = archivo
    @club     = club
    # `del_equipo`: son los candidatos a responsable de una tarea. Sin el scope, la IA podía
    # asignarle el riego a un paciente con cuenta del portal.
    @usuarios = club.users.del_equipo.select(:id, :first_name, :last_name, :email)
  end

  def interpretar
    @parse_error = nil
    texto = extraer_texto
    if texto.blank?
      msg = @parse_error ? "No se pudo leer el archivo: #{@parse_error}" : "No se pudo leer el archivo"
      return { tareas: [], ambiguas: [], total: 0, recurrentes: 0, error: msg }
    end

    if ENV["ANTHROPIC_API_KEY"].present?
      interpretar_con_ia(texto)
    else
      interpretar_csv_simple(texto)
    end
  end

  private

  def extraer_texto
    extension = File.extname(@archivo.original_filename.to_s).downcase
    case extension
    when ".csv", ".txt"
      @archivo.read.force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace)
    when ".xlsx", ".xls"
      extraer_excel
    when ".docx"
      extraer_word
    when ".pdf"
      extraer_pdf
    else
      @archivo.read.force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace) rescue nil
    end
  end

  def extraer_excel
    # Usamos RubyZip + Nokogiri (ambos disponibles como dependencias de Rails/roo)
    # sin depender del require de roo que puede fallar por bootsnap cache
    require 'zip'
    require 'nokogiri'

    ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
    shared_strings = []
    filas = []

    Zip::File.open(@archivo.path) do |zip|
      # 1. Shared strings (las celdas de texto las referencian por índice)
      if (ss = zip.find_entry('xl/sharedStrings.xml'))
        ss_doc = Nokogiri::XML(ss.get_input_stream.read)
        shared_strings = ss_doc.xpath('//xmlns:si', 'xmlns' => ns).map do |si|
          si.xpath('.//xmlns:t', 'xmlns' => ns).map(&:text).join
        end
      end

      # 2. Primera hoja
      sheet_entry = zip.find_entry('xl/worksheets/sheet1.xml') ||
                    zip.glob('xl/worksheets/sheet*.xml').first
      next unless sheet_entry

      sheet_doc = Nokogiri::XML(sheet_entry.get_input_stream.read)
      sheet_doc.xpath('//xmlns:row', 'xmlns' => ns).each do |row|
        celdas = row.xpath('xmlns:c', 'xmlns' => ns).map do |c|
          tipo = c['t']
          v    = c.at_xpath('xmlns:v', 'xmlns' => ns)&.text
          case tipo
          when 's'                 then v ? shared_strings[v.to_i].to_s : ''
          when 'str', 'inlineStr'  then c.xpath('.//xmlns:t', 'xmlns' => ns).map(&:text).join
          when 'b'                 then v == '1' ? 'TRUE' : 'FALSE'
          else                          v.to_s
          end
        end.map(&:strip).reject(&:empty?)

        filas << celdas.join(' | ') unless celdas.empty?
      end
    end

    filas.join("\n")
  rescue => e
    @parse_error = "#{e.class}: #{e.message}"
    Rails.logger.error "PlanTrabajoIaService#extraer_excel: #{@parse_error}\n#{e.backtrace.first(5).join("\n")}"
    nil
  end

  def extraer_word
    require 'docx'
    # Roo/docx necesita extensión real; copiamos el tempfile con extensión
    tmp = Tempfile.new(['plan', '.docx'])
    tmp.binmode
    @archivo.rewind
    tmp.write(@archivo.read)
    tmp.flush
    doc = Docx::Document.open(tmp.path)
    doc.paragraphs.map(&:to_s).join("\n")
  rescue LoadError
    nil
  rescue => e
    Rails.logger.error "PlanTrabajoIaService#extraer_word: #{e.message}"
    nil
  ensure
    tmp&.close!
  end

  def extraer_pdf
    require 'pdf/reader'
    tmp = Tempfile.new(['plan', '.pdf'])
    tmp.binmode
    @archivo.rewind
    tmp.write(@archivo.read)
    tmp.flush
    reader = PDF::Reader.new(tmp.path)
    reader.pages.map(&:text).join("\n")
  rescue LoadError
    nil
  rescue => e
    Rails.logger.error "PlanTrabajoIaService#extraer_pdf: #{e.message}"
    nil
  ensure
    tmp&.close!
  end

  # ── Modo IA ──────────────────────────────────────────────────

  def interpretar_con_ia(texto)
    usuarios_str = @usuarios.map { |u| "#{u.id}: #{u.first_name} #{u.last_name}" }.join(", ")

    prompt = <<~PROMPT
      Sos un asistente que interpreta planes de trabajo para una organización de cultivo de cannabis.
      Usuarios disponibles en la organización (id: nombre completo): #{usuarios_str.presence || "ninguno registrado"}

      Dado el siguiente texto, extraé todas las tareas de trabajo que describe.
      Para cada tarea devolvé un objeto JSON con estos campos exactos:
      - titulo: string (nombre de la tarea, puede ser vacío)
      - tipo: uno de exactamente estos valores [riego, poda, medicion, limpieza, cosecha, trasplante, inspeccion, otro]
      - responsable_id: integer o null (buscá el nombre en la lista de usuarios por coincidencia parcial, devolvé su id si lo encontrás)
      - responsable_nombre: string o null (nombre tal como aparece en el texto)
      - dias_semana: array de strings usando exactamente ["lun","mar","mie","jue","vie","sab","dom"] o vacío para única
      - hora: string "HH:MM" o null
      - es_recurrente: boolean (true si se repite semanalmente, false si es una fecha puntual)
      - prioridad: uno de [baja, normal, alta, urgente], default "normal"
      - descripcion: string o null
      - confianza: float entre 0 y 1 (qué tan seguro estás de la interpretación)

      Texto del plan:
      #{texto.to_s.truncate(8000)}

      Devolvé ÚNICAMENTE JSON válido con esta estructura, sin texto extra:
      {"tareas": [...], "ambiguas": [{"descripcion": "motivo del problema", "sugerencia": "qué hacer", "tarea": {...}}]}

      Las "ambiguas" son tareas que no pudiste interpretar correctamente o donde no encontraste el responsable.
    PROMPT

    resultado = llamar_claude(prompt)
    return { tareas: [], ambiguas: [], total: 0, recurrentes: 0, error: resultado[:error] } if resultado[:error]

    tareas_raw  = Array(resultado["tareas"])
    ambiguas_ia = Array(resultado["ambiguas"])

    confirmadas, dudosas = tareas_raw.partition do |t|
      t["confianza"].to_f >= 0.7 && (t["responsable_id"].present? || t["responsable_nombre"].blank?)
    end

    ambiguas_extra = dudosas.map do |t|
      motivo = if t["responsable_id"].blank? && t["responsable_nombre"].present?
                 "Persona '#{t["responsable_nombre"]}' no encontrada en la organización"
               else
                 "Datos insuficientes para confirmar automáticamente"
               end
      { "descripcion" => motivo, "sugerencia" => "Asignala manualmente antes de publicar", "tarea" => sanitizar_tarea(t) }
    end

    {
      tareas:      confirmadas.map { |t| sanitizar_tarea(t) },
      ambiguas:    ambiguas_ia + ambiguas_extra,
      total:       tareas_raw.length,
      recurrentes: tareas_raw.count { |t| t["es_recurrente"] },
    }
  end

  def llamar_claude(prompt)
    require 'net/http'
    require 'uri'

    uri     = URI("https://api.anthropic.com/v1/messages")
    http    = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.read_timeout = 45

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"]      = "application/json"
    request["x-api-key"]         = ENV["ANTHROPIC_API_KEY"]
    request["anthropic-version"] = "2023-06-01"
    request.body = {
      model:      MODELO,
      max_tokens: 4096,
      messages:   [{ role: "user", content: prompt }],
    }.to_json

    response = http.request(request)
    body     = JSON.parse(response.body)
    registrar_uso(body, ok: response.code.to_i == 200)

    if response.code.to_i != 200
      Rails.logger.error "PlanTrabajoIaService Claude error: #{body['error']&.dig('message')}"
      return { error: "Error del servicio de IA. Intentá con un CSV estructurado." }
    end

    content = body.dig("content", 0, "text").to_s.strip
    content = content.gsub(/```json\n?/, "").gsub(/```/, "").strip
    JSON.parse(content)
  rescue JSON::ParserError => e
    Rails.logger.error "PlanTrabajoIaService JSON parse error: #{e.message}"
    { error: "La IA no devolvió un formato válido. Probá con un CSV estructurado." }
  rescue => e
    Rails.logger.error "PlanTrabajoIaService llamar_claude error: #{e.message}"
    registrar_uso(nil, ok: false, error_clase: e.class.name)
    { error: "Error de conexión con el servicio de IA." }
  end

  # Sin usuario: el plan se genera desde un archivo subido y el service no recibe quién lo hizo.
  # El consumo igual es de la organización, que es lo que se factura.
  def registrar_uso(body, ok: true, error_clase: nil)
    Ia::Uso.registrar(club: @club, funcion: :plan_trabajo, modelo: MODELO,
                      tokens: Ia::Uso.tokens_de(body),
                      ok: ok, error_clase: error_clase)
  end

  # ── Modo CSV simple (fallback sin IA) ─────────────────────────

  def interpretar_csv_simple(texto)
    require 'csv'
    tareas    = []
    ambiguas  = []

    csv = CSV.parse(texto.to_s, headers: true, header_converters: :symbol, liberal_parsing: true)

    col_titulo     = csv.headers.find { |h| h.to_s =~ /titulo|tarea|nombre|task/i }
    col_tipo       = csv.headers.find { |h| h.to_s =~ /tipo|type/i }
    col_persona    = csv.headers.find { |h| h.to_s =~ /persona|responsable|asignado|usuario/i }
    col_dia        = csv.headers.find { |h| h.to_s =~ /dia|d[íi]a|day|dias/i }
    col_hora       = csv.headers.find { |h| h.to_s =~ /hora|hour|time/i }
    col_sala       = csv.headers.find { |h| h.to_s =~ /sala|room|ubicacion/i }
    col_recurrente = csv.headers.find { |h| h.to_s =~ /recurrente|repite|recurring/i }
    col_prioridad  = csv.headers.find { |h| h.to_s =~ /prioridad|priority/i }

    csv.each_with_index do |row, i|
      titulo = col_titulo ? row[col_titulo].to_s.strip : "Tarea #{i + 1}"
      next if titulo.blank?

      persona_nombre = col_persona ? row[col_persona].to_s.strip.presence : nil
      usuario = buscar_usuario(persona_nombre)

      dias_str = col_dia ? row[col_dia].to_s.strip.downcase : ""
      dias = extraer_dias(dias_str)

      tipo_raw = col_tipo ? row[col_tipo].to_s.strip.downcase : "otro"
      tipo = normalizar_tipo(tipo_raw)

      prioridad_raw = col_prioridad ? row[col_prioridad].to_s.strip.downcase : "normal"
      prioridad = PRIORIDADES_VALIDAS.include?(prioridad_raw) ? prioridad_raw : "normal"

      es_recurrente = if col_recurrente
                        !!(row[col_recurrente].to_s =~ /si|s[íi]|yes|true|1/i)
                      else
                        dias.length > 1
                      end

      tarea = {
        titulo:           titulo,
        tipo:             tipo,
        responsable_id:   usuario&.id,
        responsable_nombre: persona_nombre,
        dias_semana:      dias,
        hora:             col_hora ? row[col_hora].to_s.strip.presence : nil,
        sala:             col_sala ? row[col_sala].to_s.strip.presence : nil,
        es_recurrente:    es_recurrente,
        prioridad:        prioridad,
        descripcion:      nil,
        confianza:        usuario.present? || persona_nombre.blank? ? 0.9 : 0.5,
      }

      if usuario.nil? && persona_nombre.present?
        ambiguas << {
          "descripcion" => "Persona '#{persona_nombre}' no encontrada en la organización",
          "sugerencia"  => "Asignala manualmente antes de publicar",
          "tarea"       => tarea,
        }
      else
        tareas << tarea
      end
    end

    {
      tareas:      tareas,
      ambiguas:    ambiguas,
      total:       tareas.length + ambiguas.length,
      recurrentes: tareas.count { |t| t[:es_recurrente] },
      modo:        "csv_simple",
    }
  rescue CSV::MalformedCSVError
    {
      tareas: [], ambiguas: [], total: 0, recurrentes: 0,
      error: "No se pudo leer el archivo como CSV. Guardalo como .csv con columnas: Tarea, Tipo, Responsable, Día, Hora. Para soporte de PDF/Word/Excel activar ANTHROPIC_API_KEY.",
    }
  end

  def buscar_usuario(nombre)
    return nil if nombre.blank?
    @usuarios.find do |u|
      nombre_completo = "#{u.first_name} #{u.last_name}".downcase
      nombre.downcase.split.any? { |parte| nombre_completo.include?(parte) }
    end
  end

  def extraer_dias(str)
    return [] if str.blank?
    dias = []
    dias << "lun" if str =~ /lun|mon/
    dias << "mar" if str =~ /mar|tue/
    dias << "mie" if str =~ /mi[eé]|wed/
    dias << "jue" if str =~ /jue|thu/
    dias << "vie" if str =~ /vie|fri/
    dias << "sab" if str =~ /s[aá]b|sat/
    dias << "dom" if str =~ /dom|sun/
    dias.presence || ["lun"]
  end

  def normalizar_tipo(raw)
    case raw
    when /riego|water|rega/          then "riego"
    when /poda|trim|recort/          then "poda"
    when /medic|medi[cç]/            then "medicion"
    when /limpi|clean|aseo/          then "limpieza"
    when /cosech|harvest/            then "cosecha"
    when /trasplant|transplant/      then "trasplante"
    when /inspecc|inspect|revision/  then "inspeccion"
    else "otro"
    end
  end

  def sanitizar_tarea(t)
    tipo = TIPOS_VALIDOS.include?(t["tipo"].to_s) ? t["tipo"] : "otro"
    prio = PRIORIDADES_VALIDAS.include?(t["prioridad"].to_s) ? t["prioridad"] : "normal"
    {
      titulo:            t["titulo"].to_s,
      tipo:              tipo,
      responsable_id:    t["responsable_id"].presence,
      responsable_nombre: t["responsable_nombre"].to_s.presence,
      dias_semana:       Array(t["dias_semana"]).map(&:to_s).select { |d| %w[lun mar mie jue vie sab dom].include?(d) },
      hora:              t["hora"].to_s.presence,
      es_recurrente:     t["es_recurrente"] ? true : false,
      prioridad:         prio,
      descripcion:       t["descripcion"].to_s.presence,
      confianza:         t["confianza"].to_f,
    }
  end
end
