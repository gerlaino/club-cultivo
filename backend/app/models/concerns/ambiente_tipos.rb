module AmbienteTipos
  extend ActiveSupport::Concern

  TIPOS_CANONICOS = {
    'temperatura'          => '°C',
    'humedad'              => '%',
    'vpd'                  => 'kPa',
    'co2'                  => 'ppm',
    'ph'                   => 'pH',
    'ec'                   => 'mS/cm',
    'ppfd'                 => 'µmol/m²s',
    'lux'                  => 'lux',
    'ec_runoff'            => 'mS/cm',
    'ph_runoff'            => 'pH',
    'temperatura_sustrato' => '°C',
    'humedad_sustrato'     => '%',
    'flujo_aire'           => 'm/s',
    'oxigeno_disuelto'     => 'mg/L',
  }.freeze

  TIPOS = TIPOS_CANONICOS.keys.freeze

  included do
    validates :tipo, inclusion: { in: TIPOS, message: "'%{value}' no es un tipo de lectura válido" }
    validate  :unidad_canonica
  end

  def unidad_canonica
    return if tipo.blank? || unidad.blank?
    expected = TIPOS_CANONICOS[tipo]
    return unless expected
    return if unidad == expected
    errors.add(:unidad, "para tipo '#{tipo}' debe ser '#{expected}', recibido '#{unidad}'")
  end
end
