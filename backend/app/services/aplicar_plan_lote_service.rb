# Aplicar un plan a un lote desde su ficha. Las fechas las calcula `Planes::Calendario` y las
# tareas las va creando `Planes::Materializar` (aparecen una semana antes de su día), igual que
# desde la pantalla de planes. Antes esta puerta tenía su propia cuenta: no entendía el
# «Semana X · Día Y» de una plantilla (fallaba) y con un plan común ponía todo el día que empezó
# el lote, así que aparecía vencido de entrada.
class AplicarPlanLoteService
  def initialize(lote:, plan:, ejecutado_por:, fecha_inicio: nil)
    @lote          = lote
    @plan          = plan
    @ejecutado_por = ejecutado_por
    # Desde cuándo cuenta el plan: por defecto el inicio del lote, o la fecha que se elija.
    @fecha_inicio  = fecha_inicio.presence ? Date.parse(fecha_inicio.to_s) : @lote.start_date
    raise ArgumentError, 'El lote no tiene fecha de inicio: elegí desde cuándo cuenta el plan' if @fecha_inicio.nil?
  end

  # Todas las tareas que va a tener, con el día en que aparecen. Las que quedan antes de hoy no se
  # crean (`en_el_pasado`): un plan aplicado tarde arranca hoy, no con un mes de vencidas.
  def preview
    hoy = Time.zone.today
    calendario.ocurrencias.map { |oc| serializar(oc, hoy) }
  end

  def omitidas
    calendario.ocurrencias # las calcula
    calendario.omitidas.map { |oc| serializar(oc, Time.zone.today) }
  end

  # Devuelve [aplicación, tareas creadas ahora].
  def aplicar!
    Planes::Aplicar.call(plan: @plan, por: @ejecutado_por, fecha_inicio: @fecha_inicio, objetivo: @lote)
  end

  private

  def calendario
    @calendario ||= Planes::Calendario.new(plan: @plan, fecha_inicio: @fecha_inicio, objetivo: @lote)
  end

  def serializar(oc, hoy)
    pt = oc.plan_tarea
    {
      plan_tarea_id:  pt.id,
      titulo:         pt.titulo.presence || pt.tipo.humanize,
      tipo:           pt.tipo,
      prioridad:      pt.prioridad,
      responsable_id: oc.asignada&.id,
      responsable:    oc.asignada&.nombre_completo,
      es_recurrente:  pt.es_recurrente,
      fecha:          oc.fecha.to_s,
      en_el_pasado:   oc.fecha < hoy,
      aparece_el:     (Planes::Materializar.aparece_el(oc.fecha, hoy: hoy).to_s unless oc.fecha < hoy),
    }
  end
end
