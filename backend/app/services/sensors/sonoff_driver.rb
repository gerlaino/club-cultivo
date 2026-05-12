module Sensors
  # Driver para Sonoff TH Elite vía webhooks eWeLink.
  # Payload esperado:
  #   { "deviceid": "...", "data": { "currentTemperature": "24.5", "currentHumidity": "62" }, "triggerTime": 1693000000 }
  class SonoffDriver < BaseDriver
    def lecturas_desde(payload)
      data = payload['data'] || {}
      ts   = parse_timestamp(payload)

      lecturas = []

      temp = (data['currentTemperature'] || data['temperature'])
      lecturas << { tipo: 'temperatura', valor: temp.to_f, unidad: '°C', medido_at: ts } if temp.present?

      hum = (data['currentHumidity'] || data['humidity'])
      lecturas << { tipo: 'humedad', valor: hum.to_f, unidad: '%', medido_at: ts } if hum.present?

      lecturas
    end

    private

    def parse_timestamp(payload)
      raw = payload['triggerTime'] || payload['timestamp']
      raw.present? ? Time.zone.at(raw.to_i) : Time.current
    rescue
      Time.current
    end
  end
end
