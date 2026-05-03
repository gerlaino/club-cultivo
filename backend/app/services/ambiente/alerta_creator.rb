module Ambiente
  class AlertaCreator
    def self.call(sala:, regla:, lectura:)
      new(sala: sala, regla: regla, lectura: lectura).call
    end

    def initialize(sala:, regla:, lectura:)
      @sala    = sala
      @regla   = regla
      @lectura = lectura
    end

    def call
      Alerta.create!(
        club_id:  @sala.club_id,
        sala:     @sala,
        regla:    @regla,
        lectura:  @lectura,
        estado:   'activa',
        mensaje:  mensaje
      )
    end

    private

    def mensaje
      "#{@regla.nombre}: #{@regla.tipo_lectura} = #{@lectura.valor} #{@lectura.unidad} " \
        "(sala: #{@sala.nombre}, regla: #{condicion_texto})"
    end

    def condicion_texto
      case @regla.condicion
      when 'gt'           then "> #{@regla.umbral_a}"
      when 'lt'           then "< #{@regla.umbral_a}"
      when 'gte'          then ">= #{@regla.umbral_a}"
      when 'lte'          then "<= #{@regla.umbral_a}"
      when 'between'      then "entre #{@regla.umbral_a} y #{@regla.umbral_b}"
      when 'out_of_range' then "fuera de [#{@regla.umbral_a}, #{@regla.umbral_b}]"
      else @regla.condicion
      end
    end
  end
end
