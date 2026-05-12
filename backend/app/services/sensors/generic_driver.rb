module Sensors
  class GenericDriver < BaseDriver
    FIELD_MAP = {
      'temperatura'          => '°C',
      'humedad'              => '%',
      'co2'                  => 'ppm',
      'ppfd'                 => 'µmol/m²s',
      'ec'                   => 'mS/cm',
      'ph'                   => 'pH',
      'presion'              => 'hPa',
      'voc'                  => 'ppb',
      'lux'                  => 'lux',
      'flujo_aire'           => 'm/s',
      'oxigeno_disuelto'     => 'mg/L',
      'temperatura_sustrato' => '°C',
      'humedad_sustrato'     => '%',
    }.freeze

    def lecturas_desde(payload)
      ts = parse_timestamp(payload)
      FIELD_MAP.filter_map do |campo, unidad|
        valor = payload[campo]
        next if valor.nil?
        { tipo: campo, valor: valor.to_f, unidad: unidad, medido_at: ts }
      end
    end

    private

    def parse_timestamp(payload)
      raw = payload['timestamp']
      return Time.current unless raw.present?
      Time.zone.at(raw.to_i)
    rescue
      Time.current
    end
  end
end
