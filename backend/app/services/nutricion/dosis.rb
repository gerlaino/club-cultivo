module Nutricion
  # CUÁNTO DE UN NUTRIENTE SE USÓ, en la unidad en que se descuenta del depósito (13-oct-2026).
  #
  # Es la única cuenta entre «lo que se dijo» (o lo que dice la etiqueta) y lo que sale del
  # depósito. La usan el dictado (`DesdeDictado`) y la dosis de la etiqueta del nutriente.
  #
  # Una cantidad tiene QUÉ y POR CADA QUÉ:
  #   medida: 'ml' | 'g' | 'medida' (la medida casera del nutriente: pulso, tapita…)
  #   por:    'total' | 'litro' (de agua) | 'planta'
  # «Un pulso a cada planta» = 1 medida por planta; «2 ml por litro» = 2 ml por litro;
  # «50 ml de vege» = 50 ml en total.
  #
  # Lo que no se puede calcular no se adivina: vuelve `falta` (los litros, las plantas o cuánto es
  # una medida) y la pantalla lo pregunta antes de guardar.
  class Dosis
    Resultado = Struct.new(:cantidad, :detalle, :falta, keyword_init: true)

    MEDIDAS = %w[ml g medida].freeze
    POR     = %w[total litro planta].freeze

    # La unidad guardada en el nutriente (`Insumo::DOSIS_UNIDADES`, «ml_litro») → [medida, por].
    def self.partes_de(dosis_unidad)
      medida, por = dosis_unidad.to_s.split('_', 2)
      [medida, por]
    end

    def self.calcular(insumo:, valor:, medida:, por: 'total', litros: nil, plantas: nil)
      new(insumo: insumo, valor: valor, medida: medida, por: por, litros: litros, plantas: plantas).call
    end

    def initialize(insumo:, valor:, medida:, por:, litros:, plantas:)
      @insumo  = insumo
      @valor   = valor.to_d
      @medida  = medida.to_s
      @por     = por.to_s.presence || 'total'
      @litros  = litros.presence&.to_d
      @plantas = plantas.presence&.to_i
    end

    def call
      return sin('valor') unless @valor.positive? && MEDIDAS.include?(@medida) && POR.include?(@por)

      # 1) Por cada qué: cuántas «veces» se aplica la dosis.
      veces = case @por
              when 'total'  then 1
              when 'litro'  then (@litros&.positive? ? @litros : (return sin('litros')))
              when 'planta' then (@plantas&.positive? ? @plantas : (return sin('plantas')))
              end
      total = @valor * veces

      # 2) Qué: la medida casera se pasa a ml o g.
      if @medida == 'medida'
        return sin('medida') unless @insumo.medida_casera_cantidad.to_d.positive?
        chica = unidad_chica
        total_chica = total * @insumo.medida_casera_cantidad.to_d
      else
        chica = @medida == 'ml' ? 'mililitro' : 'gramo'
        total_chica = total
      end

      # 3) A la unidad en que vive el nutriente (un bidón cargado en litros, una bolsa en kg).
      cantidad = (total_chica * factor(chica)).round(3)
      Resultado.new(cantidad: cantidad, detalle: detalle(veces), falta: nil)
    end

    private

    def sin(que) = Resultado.new(cantidad: nil, detalle: nil, falta: que)

    # La medida casera se mide en ml si el producto es líquido y en g si es sólido.
    def unidad_chica
      case @insumo.unidad_medida
      when 'litro', 'mililitro'   then 'mililitro'
      when 'kilogramo', 'gramo'   then 'gramo'
      else @insumo.unidad_medida
      end
    end

    def factor(chica)
      return BigDecimal('1') if chica == @insumo.unidad_medida
      RecetaItem::CONVERSION[[chica, @insumo.unidad_medida]] || BigDecimal('1')
    end

    # «1 pulso × 6 plantas», «2 ml × 3 L»: la cuenta a la vista, para que se pueda corregir.
    def detalle(veces)
      que = case @medida
            when 'medida' then nombre_medida(@valor)
            when 'ml'     then "#{num(@valor)} ml"
            else "#{num(@valor)} g"
            end
      case @por
      when 'total'  then que
      when 'litro'  then "#{que} × #{num(veces)} L"
      when 'planta' then "#{que} × #{veces} planta#{veces == 1 ? '' : 's'}"
      end
    end

    def nombre_medida(n)
      nombre = @insumo.medida_casera.presence || 'medida'
      plural = n == 1 ? nombre : (nombre.end_with?('s') ? nombre : "#{nombre}s")
      "#{num(n)} #{plural}"
    end

    def num(n) = (n.to_d % 1).zero? ? n.to_i.to_s : n.to_d.round(3).to_s('F').sub('.', ',')
  end
end
