module Camas
  # Registra algo hecho al suelo de una cama (`CamaRegistro`) y, si usó insumos, los aplica:
  # descuenta, cuesta y deja la copia (`Nutricion::Aplicar`). Una sola puerta para el armado (desde
  # el alta de la cama), el «Alimentar la cama» (desde la cama, el lote o el «+») y el riego de la
  # cama que descansa.
  #
  # La receta tiene que ser del uso que corresponde al tipo: el top dress se dosifica por m², la
  # mezcla por litro de suelo y el té por litro de agua. La base sale de la cama (sus m² o sus litros
  # de suelo) salvo que venga otra: un top dress sobre la mitad de la cama es la mitad de los m².
  class Registrar
    Result = Struct.new(:ok, :error, :registro, :faltantes, keyword_init: true) do
      def ok? = ok
    end

    USO_POR_TIPO = { 'armado' => 'mezcla', 'top_dress' => 'top_dress', 'te' => 'riego', 'riego' => 'riego' }.freeze

    def self.call(**kw) = new(**kw).call

    # attrs: tipo, registrado_en, detalle, cantidad, unidad, litros, agua, humedad_suelo,
    #        temperatura_suelo, recarga, observaciones.
    # nutricion: { receta_id, base, items: [{ insumo_id, cantidad, modo_faltante }] }
    def initialize(cama:, usuario:, attrs:, nutricion: nil)
      @cama, @usuario = cama, usuario
      @attrs     = attrs.to_h.symbolize_keys
      @nutricion = nutricion.respond_to?(:to_unsafe_h) ? nutricion.to_unsafe_h : nutricion.to_h
      @nutricion = @nutricion.deep_symbolize_keys
    end

    def call
      tipo = @attrs[:tipo].to_s
      receta = nil
      if @nutricion[:receta_id].present?
        receta = @cama.club.recetas.find_by(id: @nutricion[:receta_id])
        return err('Receta no encontrada') unless receta
        uso = USO_POR_TIPO[tipo]
        return err("#{CamaRegistro::TIPO_LABELS[tipo] || tipo} no lleva receta: cargá los productos sueltos") if uso.nil?
        if receta.uso != uso
          return err("La receta «#{receta.nombre}» es de #{Receta::USO_LABELS[receta.uso].downcase}: para " \
                     "#{CamaRegistro::TIPO_LABELS[tipo].downcase} va una de #{Receta::USO_LABELS[uso].downcase}")
        end
      end
      items = Array(@nutricion[:items]).map { |i| i.to_h.symbolize_keys }.presence
      if (receta || items) && !CamaRegistro::CON_INSUMOS.include?(tipo)
        return err("#{CamaRegistro::TIPO_LABELS[tipo] || tipo} no descuenta productos")
      end

      registro = @cama.registros.new(@attrs.merge(club: @cama.club, user: @usuario))
      registro.registrado_en ||= Time.current
      faltantes = []
      ActiveRecord::Base.transaction do
        registro.save!
        if receta || items
          base = @nutricion[:base].presence || base_por_defecto(receta, registro)
          if receta && base.to_d <= 0
            raise ActiveRecord::RecordInvalid.new(registro.tap { |r| r.errors.add(:base, falta_base(receta)) })
          end
          faltantes = Nutricion::Aplicar.new(club: @cama.club, usuario: @usuario, cama_registro: registro,
                                             receta: receta, items: items, base: base, litros: registro.litros).call.faltantes
        end
      end
      Result.new(ok: true, registro: registro.reload, faltantes: faltantes)
    rescue ActiveRecord::RecordInvalid => e
      err(e.record.errors.full_messages.join(', '))
    end

    private

    def err(msg) = Result.new(ok: false, error: msg)

    def base_por_defecto(receta, registro)
      case receta&.uso
      when 'top_dress' then @cama.m2
      when 'mezcla'    then @cama.litros_suelo
      else registro.litros
      end
    end

    def falta_base(receta)
      case receta.uso
      when 'top_dress' then 'Para calcular la receta faltan los m²: cargá el largo y el ancho de la cama, o cuántos m² alimentaste'
      when 'mezcla'    then 'Para calcular la mezcla faltan los litros de suelo: cargá las medidas de la cama (con la profundidad)'
      else 'Para calcular la receta faltan los litros'
      end
    end
  end
end
