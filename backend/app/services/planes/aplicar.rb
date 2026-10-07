module Planes
  # Aplicar un plan: deja anotada la aplicación (para verla, seguirla y cancelarla) y crea ya lo
  # de esta semana. El resto lo va creando `Planes::Materializar` cada día. Es la única forma de
  # aplicar un plan: la usan el lote, la pantalla de planes y publicar un plan con fechas.
  class Aplicar
    def self.call(plan:, por:, fecha_inicio:, objetivo: nil)
      aplicacion = plan.club.aplicacion_planes.create!(
        plan_trabajo:   plan,
        aplicado_por:   por,
        fecha_inicio:   fecha_inicio,
        objetivo_tipo:  objetivo&.class&.name,
        objetivo_id:    objetivo&.id,
        estado:         'activo',
        tareas_creadas: 0
      )
      creadas = Materializar.call(aplicacion)
      [aplicacion, creadas]
    end
  end
end
