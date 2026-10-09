module Planes
  # Crea las tareas de un plan aplicado DE A POCO: cada una aparece `VENTANA_DIAS` días antes de su
  # fecha (Germán, 7-oct-2026). Crear el ciclo entero al aplicarlo llenaba las listas de tareas de
  # dentro de tres meses. Lo corre `MaterializarTareasDePlanesJob` todos los días, y cada puerta que
  # aplica un plan lo llama en el momento para que lo de esta semana ya esté.
  #
  # Reglas:
  #   - Nada ANTERIOR al día en que se aplicó: un plan aplicado a un lote que empezó hace un mes
  #     arranca hoy, no deja un mes de tareas vencidas.
  #   - Nunca dos veces la misma (tarea del plan + día + persona). Tampoco vuelve a crear una que
  #     alguien borró, canceló o marcó «no se hizo»: se cuenta todo, también lo borrado.
  #   - Sólo mientras la aplicación esté activa y su lote siga en el ciclo. Cancelar el plan, o que
  #     el lote termine, corta lo que falta.
  #   - Un `with_lock` sobre la aplicación: el proceso diario y una aplicación manual al mismo tiempo
  #     no pueden crear la misma tarea dos veces.
  class Materializar
    VENTANA_DIAS = 7
    LOTE_TERMINADO = %w[finalizado].freeze

    def self.call(aplicacion, hoy: Time.zone.today) = new(aplicacion, hoy).call

    def initialize(aplicacion, hoy)
      @aplicacion = aplicacion
      @hoy        = hoy
    end

    # Lo que el plan tiene programado y TODAVÍA NO es una tarea, entre dos fechas: el calendario lo
    # muestra como previsto (9-oct-2026, Germán: miraba la semana del 23 y estaba vacía aunque el
    # plan ya sabía que ese viernes tocaba poda). Las mismas reglas que `call`: lo que `call` va a
    # crear cuando entre en la ventana es exactamente lo que esto devuelve.
    def self.pendientes(aplicacion, desde:, hasta:, hoy: Time.zone.today)
      m = new(aplicacion, hoy)
      objetivo = m.send(:objetivo_vigente)
      return [] unless objetivo

      ya = m.send(:ya_creadas)
      m.send(:calendario, objetivo).ocurrencias.select do |oc|
        oc.fecha >= desde && oc.fecha <= hasta && oc.fecha >= m.send(:desde) &&
          !ya.include?([oc.plan_tarea.id, oc.fecha, oc.asignada&.id])
      end
    end

    def call
      objetivo = objetivo_vigente
      return [] unless objetivo

      creadas = []
      @aplicacion.with_lock do
        ya = ya_creadas

        calendario(objetivo).ocurrencias.each do |oc|
          next if oc.fecha < desde || oc.fecha > hasta

          clave = [oc.plan_tarea.id, oc.fecha, oc.asignada&.id]
          next if ya.include?(clave)

          creadas << crear!(oc, objetivo)
          ya << clave
        end
        @aplicacion.update_columns(tareas_creadas: @aplicacion.tareas_creadas.to_i + creadas.size) if creadas.any?
      end
      creadas
    end

    # Para mostrar antes de aplicar y en el detalle: todas las ocurrencias, con el día en que van a
    # aparecer en las listas.
    def self.aparece_el(fecha, hoy: Time.zone.today) = [fecha - VENTANA_DIAS.days, hoy].max

    private

    # El objetivo si el plan sigue corriendo sobre él; nil si ya no hay nada que crear. Una aplicación
    # sin objetivo (todo el cultivo) devuelve `true`.
    def objetivo_vigente
      return nil unless @aplicacion.estado == 'activo'
      return true if @aplicacion.objetivo_tipo.blank?

      objetivo = @aplicacion.objetivo
      return nil if objetivo.nil? # el lote o la sala ya no está
      return nil if objetivo.is_a?(Lote) && LOTE_TERMINADO.include?(objetivo.estado)

      objetivo
    end

    # Nunca dos veces la misma: se cuenta todo, también lo borrado.
    def ya_creadas
      Tarea.with_deleted.where(aplicacion_plan_id: @aplicacion.id)
           .pluck(:plan_tarea_id, :fecha_programada, :asignada_a_id).to_set
    end

    def desde = @aplicacion.created_at.in_time_zone.to_date
    def hasta = @hoy + VENTANA_DIAS.days

    def calendario(objetivo)
      Calendario.new(plan: @aplicacion.plan_trabajo, fecha_inicio: @aplicacion.fecha_inicio,
                     objetivo: (objetivo unless objetivo == true), corte: @aplicacion.created_at)
    end

    def crear!(oc, objetivo)
      pt    = oc.plan_tarea
      plan  = @aplicacion.plan_trabajo
      lote  = objetivo.is_a?(Lote) ? objetivo : nil
      sala  = objetivo.is_a?(Sala) ? objetivo : nil

      @aplicacion.club.tareas.create!(
        titulo:             pt.titulo.presence || pt.tipo.humanize,
        descripcion:        pt.descripcion,
        tipo:               pt.tipo,
        estado:             'pendiente',
        prioridad:          pt.prioridad,
        asignada_a_id:      oc.asignada&.id,
        sala_id:            pt.sala_id || sala&.id || lote&.sala_id,
        lote_id:            lote&.id,
        fecha_programada:   oc.fecha,
        recurrente:         false,
        creada_por_id:      @aplicacion.aplicado_por_id,
        origen_plan_id:     plan.id,
        origen_plan_titulo: plan.titulo,
        plan_tarea_id:      pt.id,
        aplicacion_plan_id: @aplicacion.id
      )
    end
  end
end
