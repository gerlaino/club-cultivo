module Sensors
  # Abstract base for sensor drivers. Subclasses implement #lecturas_desde(payload).
  class BaseDriver
    attr_reader :dispositivo

    def initialize(dispositivo)
      @dispositivo = dispositivo
    end

    # Returns array of hashes: { tipo:, valor:, unidad:, medido_at: }
    def lecturas_desde(_payload)
      raise NotImplementedError, "#{self.class}#lecturas_desde no implementado"
    end

    def persist!(payload)
      lecturas_desde(payload).each do |attrs|
        LecturaAmbiental.find_or_initialize_by(
          dispositivo_id: dispositivo.id,
          tipo:           attrs[:tipo],
          medido_at:      attrs[:medido_at]
        ).tap do |l|
          l.assign_attributes(
            club_id:  dispositivo.club_id,
            sala_id:  dispositivo.sala_id,
            valor:    attrs[:valor],
            unidad:   attrs[:unidad],
            fuente:   'webhook'
          )
          l.save!
        end
      end
    end
  end
end
