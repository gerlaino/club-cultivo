require 'csv'
require 'net/http'
require 'json'

module Sensors
  class AiCsvDriver
    TIPOS_CANONICOS = {
      'temperatura'          => '°C',
      'humedad'              => '%',
      'co2'                  => 'ppm',
      'ec'                   => 'mS/cm',
      'ph'                   => 'pH',
      'ppfd'                 => 'µmol/m²s',
      'vpd'                  => 'kPa',
      'temperatura_sustrato' => '°C',
      'humedad_sustrato'     => '%',
    }.freeze

    MODELO = 'claude-haiku-4-5-20251001'.freeze

    class CsvParseError < StandardError; end

    def initialize(sala, registrado_por)
      @sala          = sala
      @registrado_por = registrado_por
    end

    # Returns { importadas: N, total: M, mapping: {...} }
    def importar!(csv_content)
      csv_content = csv_content.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace)
      csv_content = csv_content.sub("\xEF\xBB\xBF", '') # strip BOM

      tabla = CSV.parse(csv_content, headers: true, skip_blanks: true)
      raise CsvParseError, 'El archivo CSV está vacío o no tiene encabezados' if tabla.headers.blank? || tabla.empty?

      headers     = tabla.headers.compact.map(&:strip)
      sample_rows = tabla.first(5).map { |r| r.to_h.transform_values { |v| v&.strip } }

      mapping = detectar_columnas_con_ia(headers, sample_rows)
      raise CsvParseError, 'No se pudo detectar la columna de fecha/hora en el CSV' unless mapping['medido_at']

      importadas = 0
      errores    = 0

      tabla.each do |row|
        row_h = row.to_h.transform_values { |v| v&.strip }

        timestamp_raw = row_h[mapping['medido_at']]
        next if timestamp_raw.blank?

        medido_at = parsear_timestamp(timestamp_raw, mapping['date_format'])
        next if medido_at.nil?

        (mapping['campos'] || {}).each do |tipo, columna|
          next if columna.blank? || TIPOS_CANONICOS[tipo].nil?
          valor_raw = row_h[columna]
          next if valor_raw.blank?

          valor = valor_raw.gsub(',', '.').to_f
          next if valor == 0 && tipo != 'ph'

          begin
            LecturaAmbiental.upsert(
              {
                club_id:       @sala.club_id,
                sala_id:       @sala.id,
                tipo:          tipo,
                valor:         valor,
                unidad:        TIPOS_CANONICOS[tipo],
                medido_at:     medido_at,
                fuente:        'csv_import',
                created_at:    Time.current,
                updated_at:    Time.current,
              },
              unique_by:      %i[sala_id tipo medido_at],
              update_only:    %i[valor updated_at],
            )
            importadas += 1
          rescue => e
            errores += 1
            Rails.logger.warn "AiCsvDriver upsert error: #{e.message}"
          end
        end
      end

      { importadas: importadas, filas: tabla.size, errores: errores, mapping: mapping }
    end

    private

    def detectar_columnas_con_ia(headers, sample_rows)
      api_key = ENV['ANTHROPIC_API_KEY']
      raise CsvParseError, 'ANTHROPIC_API_KEY no configurada' if api_key.blank?

      prompt = <<~PROMPT
        Tenés los headers y primeras filas de un CSV exportado desde un sensor ambiental (Bluelab, Apogee, u otro).

        Headers disponibles: #{headers.to_json}
        Primeras filas (muestra): #{sample_rows.to_json}

        Tu tarea: identificar qué columna corresponde a cada campo ambiental.

        Respondé SOLO con JSON válido, sin markdown, sin texto extra:
        {
          "medido_at": "<nombre exacto de la columna de fecha/hora, o null>",
          "date_format": "<uno de: iso8601 | dmy_hms | mdy_hms | dmy | mdy | unix_ts>",
          "campos": {
            "temperatura": "<columna exacta o null>",
            "humedad": "<columna exacta o null>",
            "ec": "<columna exacta o null>",
            "ph": "<columna exacta o null>",
            "co2": "<columna exacta o null>",
            "ppfd": "<columna exacta o null>",
            "vpd": "<columna exacta o null>",
            "temperatura_sustrato": "<columna exacta o null>",
            "humedad_sustrato": "<columna exacta o null>"
          }
        }

        Reglas:
        - Usá null para campos que no existen en este CSV.
        - "ec" puede aparecer como EC, EC (mS/cm), Conductivity, TDS.
        - "ph" puede aparecer como pH, PH, Acidity.
        - "temperatura" puede aparecer como Temp, Temperature, Temp (°C), Temperatura.
        - "date_format" iso8601 = YYYY-MM-DD HH:MM:SS o ISO. dmy_hms = DD/MM/YYYY HH:MM:SS. mdy_hms = MM/DD/YYYY HH:MM:SS. unix_ts = número entero UNIX.
        - Los nombres de columna deben ser exactamente como aparecen en los headers.
      PROMPT

      uri  = URI('https://api.anthropic.com/v1/messages')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = true
      http.read_timeout = 20

      req = Net::HTTP::Post.new(uri)
      req['Content-Type']      = 'application/json'
      req['x-api-key']         = api_key
      req['anthropic-version'] = '2023-06-01'
      req.body = {
        model:      MODELO,
        max_tokens: 512,
        messages:   [{ role: 'user', content: prompt }],
      }.to_json

      response = http.request(req)
      body     = JSON.parse(response.body)

      entrada, salida = Ia::Uso.tokens_de(body)
      Ia::Uso.registrar(club: @sala.club, user: @registrado_por, funcion: :csv_import,
                        modelo: MODELO, input_tokens: entrada, output_tokens: salida,
                        ok: response.code.to_i == 200)

      raise CsvParseError, "IA error #{response.code}: #{body.dig('error', 'message')}" if response.code.to_i != 200

      raw = body.dig('content', 0, 'text').to_s.strip
      raw = raw.gsub(/```json\n?/, '').gsub(/```/, '').strip

      JSON.parse(raw)
    rescue JSON::ParserError
      raise CsvParseError, 'La IA devolvió un formato inesperado'
    rescue CsvParseError
      raise
    rescue => e
      Rails.logger.error "AiCsvDriver#detectar_columnas_con_ia: #{e.message}"
      raise CsvParseError, 'Error al conectar con la IA'
    end

    def parsear_timestamp(str, format)
      str = str.to_s.strip
      case format
      when 'iso8601'
        Time.zone.parse(str)
      when 'dmy_hms'
        Time.zone.strptime(str, '%d/%m/%Y %H:%M:%S') rescue Time.zone.strptime(str, '%d/%m/%Y %H:%M')
      when 'mdy_hms'
        Time.zone.strptime(str, '%m/%d/%Y %H:%M:%S') rescue Time.zone.strptime(str, '%m/%d/%Y %H:%M')
      when 'dmy'
        Time.zone.strptime(str, '%d/%m/%Y')
      when 'mdy'
        Time.zone.strptime(str, '%m/%d/%Y')
      when 'unix_ts'
        Time.zone.at(str.to_i)
      else
        Time.zone.parse(str)
      end
    rescue ArgumentError, TypeError
      nil
    end
  end
end
