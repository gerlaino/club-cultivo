module Riegos
  # EL RIEGO POR PLANTA (Germán, 30-sep-2026). Desde el riego del lote se eligen plantas por
  # TANDAS: cada tanda es un grupo de plantas y cuánto recibió cada una, en litros o en pulsos
  # (con cuántos litros es un pulso). Crea una fila por planta y el volumen del registro pasa a
  # ser la suma: el número del lote sigue siendo lo que recibió el lote.
  #
  # tandas: [{ plant_ids: [..], litros: 0.5 } | { plant_ids: [..], pulsos: 2, litros_por_pulso: 0.25 }]
  #
  # Sólo plantas EN PIE del lote (una cortada o descartada no se riega), y cada planta en una
  # sola tanda: dos tandas para la misma planta es un error de carga, no un riego doble.
  class PorPlanta
    def initialize(registro:, tandas:)
      @registro = registro
      @tandas   = Array(tandas).map { |t| t.respond_to?(:to_unsafe_h) ? t.to_unsafe_h : t.to_h }.map(&:symbolize_keys)
    end

    def call
      raise ArgumentError, 'Elegí al menos una planta' if @tandas.empty?

      en_pie = @registro.lote.plants.en_pie.pluck(:id).to_set
      vistas = Set.new
      filas = @tandas.flat_map do |t|
        ids = Array(t[:plant_ids]).map(&:to_i).uniq
        raise ArgumentError, 'Cada tanda lleva al menos una planta' if ids.empty?
        raise ArgumentError, 'Una planta elegida no está en pie en este lote' unless ids.all? { |id| en_pie.include?(id) }
        raise ArgumentError, 'Una planta está en dos tandas' if ids.any? { |id| vistas.include?(id) }

        vistas.merge(ids)
        cantidad = cantidad_de(t)
        ids.map { |id| cantidad.merge(plant_id: id) }
      end

      filas.each { |f| @registro.riego_plantas.create!(club: @registro.club, **f) }
      @registro.update_columns(volumen_l: filas.sum { |f| f[:volumen_l] })
      @registro
    end

    private

    def cantidad_de(t)
      if t[:pulsos].present?
        pulsos = t[:pulsos].to_d
        lpp    = t[:litros_por_pulso].to_d
        raise ArgumentError, 'Decí cuántos litros es un pulso' unless lpp.positive?
        raise ArgumentError, 'Los pulsos tienen que ser más que 0' unless pulsos.positive?
        { volumen_l: (pulsos * lpp).round(2), pulsos: pulsos, litros_por_pulso: lpp }
      else
        litros = t[:litros].to_d
        raise ArgumentError, 'Decí cuánta agua recibió cada planta' unless litros.positive?
        { volumen_l: litros }
      end
    end
  end
end
