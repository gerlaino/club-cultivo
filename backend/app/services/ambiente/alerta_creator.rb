module Ambiente
  class AlertaCreator
    # Acciones de ReglaAmbiental que además de notificar abren una tarea de revisión.
    ACCIONES_CON_TAREA      = %w[crear_tarea todas].freeze
    # ReglaAmbiental.prioridad (baja/media/alta/critica) → Tarea.prioridad.
    PRIORIDAD_REGLA_A_TAREA = { 'baja' => 'baja', 'media' => 'normal', 'alta' => 'alta', 'critica' => 'urgente' }.freeze

    def self.call(sala:, regla:, lectura:)
      new(sala: sala, regla: regla, lectura: lectura).call
    end

    def initialize(sala:, regla:, lectura:)
      @sala    = sala
      @regla   = regla
      @lectura = lectura
    end

    def call
      alerta = Alerta.create!(
        club_id:  @sala.club_id,
        sala:     @sala,
        regla:    @regla,
        lectura:  @lectura,
        estado:   'activa',
        mensaje:  mensaje
      )
      crear_tarea_si_corresponde
      alerta
    end

    private

    # Si la regla lo pide, abre una tarea de inspección para que alguien revise el
    # desvío. Aditivo a la alerta (no la reemplaza). Se dispara solo cuando el
    # evaluador confirma una violación nueva (dedup por alerta activa), así que no
    # spamea. No rompe la ingesta de lecturas si algo falla (rescue + log).
    def crear_tarea_si_corresponde
      return unless ACCIONES_CON_TAREA.include?(@regla.accion)

      usuario = @sala.responsable || @sala.club.users.find_by(role: 'admin')
      return unless usuario # creada_por es obligatorio: sin usuario no hay tarea

      Tarea.create!(
        club_id:          @sala.club_id,
        creada_por:       usuario,
        asignada_a:       usuario,
        sala:             @sala,
        titulo:           "Revisar #{@regla.tipo_lectura} en #{@sala.nombre} (#{condicion_texto})".first(200),
        descripcion:      mensaje,
        tipo:             'inspeccion',
        prioridad:        PRIORIDAD_REGLA_A_TAREA[@regla.prioridad] || 'normal',
        estado:           'pendiente',
        fecha_programada: Date.today
      )
    rescue StandardError => e
      Rails.logger.warn("[AlertaCreator] No se pudo crear tarea para regla #{@regla.id}: #{e.message}")
    end

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
