class AplicarPlanLoteService
  DIAS_A_WDAY = { 'lun' => 1, 'mar' => 2, 'mie' => 3, 'jue' => 4, 'vie' => 5, 'sab' => 6, 'dom' => 0 }.freeze

  def initialize(lote:, plan:, ejecutado_por:, fecha_inicio: nil)
    @lote          = lote
    @plan          = plan
    @ejecutado_por = ejecutado_por
    # Fecha de anclaje del plan. Por defecto el inicio del lote, pero se puede
    # elegir otra (p. ej. un lote heredado que empezó hace 2 semanas → las tareas
    # se generan desde esa fecha, incluso en el pasado, para un registro fiel).
    @fecha_inicio  = fecha_inicio.presence ? Date.parse(fecha_inicio.to_s) : @lote.start_date
  end

  def preview
    calcular_propuestas
  end

  def aplicar!
    propuestas = calcular_propuestas
    creadas    = []
    ActiveRecord::Base.transaction do
      # Registrar la aplicación para que sea visible y reversible
      # (mismo modelo que usa AplicacionPlanesController)
      aplicacion = @lote.club.aplicacion_planes.create!(
        plan_trabajo:   @plan,
        aplicado_por:   @ejecutado_por,
        fecha_inicio:   @fecha_inicio,
        objetivo_tipo:  'Lote',
        objetivo_id:    @lote.id,
        estado:         'activo',
        tareas_creadas: 0
      )

      propuestas.each do |td|
        creadas << @lote.club.tareas.create!(
          titulo:           td[:titulo],
          tipo:             td[:tipo],
          estado:           'pendiente',
          prioridad:        td[:prioridad],
          asignada_a_id:    td[:responsable_id],
          sala_id:          @lote.sala_id,
          lote_id:          @lote.id,
          fecha_programada: Date.parse(td[:fecha]),
          recurrente:       false,
          creada_por:       @ejecutado_por,
          origen_plan_id:   @plan.id,
          plan_tarea_id:    td[:plan_tarea_id],
          aplicacion_plan_id: aplicacion.id,
        )
      end

      aplicacion.update!(tareas_creadas: creadas.size)
    end
    creadas
  end

  private

  def calcular_propuestas
    base     = @fecha_inicio
    offset   = (base - @plan.fecha_inicio).to_i
    fin_date = @plan.fecha_fin + offset.days

    tareas = []

    @plan.plan_tareas.includes(:responsable).each do |pt|
      if pt.es_recurrente? && pt.dias_semana.present?
        wdays = pt.dias_array.filter_map { |d| DIAS_A_WDAY[d] }
        fecha = base
        while fecha <= fin_date
          tareas << serializar(pt, fecha) if wdays.include?(fecha.wday)
          fecha += 1.day
        end
      else
        fecha = if pt.fecha_especifica.present?
                  pt.fecha_especifica + offset.days
                else
                  base
                end
        tareas << serializar(pt, fecha)
      end
    end

    tareas.sort_by { |t| t[:fecha] }
  end

  def serializar(pt, fecha)
    {
      plan_tarea_id:  pt.id,
      titulo:         pt.titulo.presence || pt.tipo.humanize,
      tipo:           pt.tipo,
      prioridad:      pt.prioridad,
      responsable_id: pt.responsable_id,
      responsable:    pt.responsable&.nombre_completo,
      es_recurrente:  pt.es_recurrente,
      fecha:          fecha.to_s,
    }
  end
end
