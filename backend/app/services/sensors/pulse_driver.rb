module Sensors
  # Driver para Pulse (pulsegrow.com) — temperatura, humedad, VPD y lo que el equipo mida.
  #
  # `pulse` ya estaba en Dispositivo::TIPOS pero sin driver propio, así que caía en el
  # genérico: sólo se leían las claves que coinciden con nuestros nombres en castellano, y
  # Pulse las manda en inglés. En la práctica, un Pulse conectado no registraba nada.
  #
  # Acepta las dos formas en que puede llegar el dato:
  #   plano   → { "temperature": 24.5, "humidity": 62, "vpd": 1.2, "timestamp": 1693000000 }
  #   anidado → { "data": { "temperatureC": 24.5, "humidityRh": 62 }, "createdAt": "2026-08-07T12:00:00Z" }
  #
  # El VPD que manda el equipo se IGNORA a propósito: la app lo calcula sola a partir de la
  # temperatura y la humedad (ver LecturaAmbiental#calcular_vpd_automatico), igual para todos
  # los sensores. Guardar además el del equipo daría dos números para lo mismo —y distintos,
  # porque cada fabricante usa su propia fórmula—, que es justo lo que hace desconfiar de un
  # dato. Un solo VPD, comparable entre salas y entre marcas.
  class PulseDriver < BaseDriver
    # Cada tipo nuestro, con los nombres que Pulse puede usar y su unidad.
    CAMPOS = {
      'temperatura'          => { claves: %w[temperature temperatureC temp air_temperature], unidad: '°C' },
      'humedad'              => { claves: %w[humidity humidityRh rh relative_humidity],      unidad: '%' },
      'co2'                  => { claves: %w[co2 co2Ppm carbon_dioxide],                     unidad: 'ppm' },
      'ppfd'                 => { claves: %w[ppfd par lightPpfd],                            unidad: 'µmol/m²s' },
      'presion'              => { claves: %w[pressure barometricPressure],                   unidad: 'hPa' },
      'voc'                  => { claves: %w[voc vocPpb],                                    unidad: 'ppb' },
      'lux'                  => { claves: %w[lux light illuminance],                         unidad: 'lux' },
      'temperatura_sustrato' => { claves: %w[substrateTemperature soilTemperature],          unidad: '°C' },
      'humedad_sustrato'     => { claves: %w[substrateHumidity soilMoisture vwc],            unidad: '%' },
    }.freeze

    def lecturas_desde(payload)
      datos = payload['data'].is_a?(Hash) ? payload['data'].merge(payload.except('data')) : payload
      ts    = parse_timestamp(payload, datos)

      CAMPOS.filter_map do |tipo, cfg|
        valor = cfg[:claves].filter_map { |k| datos[k] }.first
        next if valor.nil? || valor.to_s.strip.empty?

        { tipo: tipo, valor: valor.to_f, unidad: cfg[:unidad], medido_at: ts }
      end
    end

    private

    # Pulse puede mandar epoch (segundos o milisegundos) o una fecha ISO. Si no viene nada,
    # la lectura es de ahora: es peor descartarla que fecharla con el momento en que llegó.
    def parse_timestamp(payload, datos)
      raw = payload['timestamp'] || payload['createdAt'] || payload['recordedAt'] ||
            datos['timestamp'] || datos['createdAt']
      return Time.current if raw.blank?

      if raw.to_s.match?(/\A\d+\z/)
        n = raw.to_i
        # Más de 10 dígitos es milisegundos: fechado en segundos daría el año 50.000.
        Time.zone.at(n > 99_999_999_999 ? n / 1000 : n)
      else
        Time.zone.parse(raw.to_s) || Time.current
      end
    rescue StandardError
      Time.current
    end
  end
end
