module Ambiente
  # Evaluates environmental rules against recent readings for a given sala.
  # Called after each LecturaAmbiental is persisted.
  class EvaluadorReglas
    VENTANA_MINUTOS = 15

    def initialize(sala)
      @sala = sala
    end

    def self.call(sala)
      new(sala).call
    end

    def call
      reglas = ReglaAmbiental.activas_para_sala(@sala.id)
      reglas.each { |regla| evaluar(regla) }
    end

    private

    def evaluar(regla)
      # Ignore backfill-sourced readings to avoid historical false alerts
      lecturas = LecturaAmbiental
        .de_sala(@sala.id)
        .del_tipo(regla.tipo_lectura)
        .no_backfill
        .ultimas_n_minutos(regla.duracion_minutos)
        .order(medido_at: :asc)

      return if lecturas.empty?
      return unless todas_violan?(lecturas, regla)

      return if regla.alerta_activa_para?(@sala.id)

      AlertaCreator.call(
        sala:    @sala,
        regla:   regla,
        lectura: lecturas.last
      )
    end

    def todas_violan?(lecturas, regla)
      lecturas.all? { |l| regla.viola?(l.valor) }
    end
  end
end
