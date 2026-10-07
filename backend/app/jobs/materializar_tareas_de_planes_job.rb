# Todos los días, de madrugada: crea las tareas de los planes aplicados que entran en la semana
# (`Planes::Materializar`). Así las listas muestran lo próximo y no el ciclo entero.
#
# Una aplicación que falla no frena a las demás. Correrlo dos veces no duplica nada: cada tarea se
# reconoce por (tarea del plan, día, persona).
class MaterializarTareasDePlanesJob < ApplicationJob
  queue_as :default

  def perform
    creadas = 0
    cada_club_con(:cultivo) do |club|
      club.aplicacion_planes.activos.includes(:plan_trabajo).find_each do |aplicacion|
        creadas += Planes::Materializar.call(aplicacion).size
      rescue StandardError => e
        Rails.logger.error("[PLANES] no se pudo materializar la aplicación ##{aplicacion.id}: #{e.class} #{e.message}")
      end
    end
    Rails.logger.info("[PLANES] tareas de planes creadas: #{creadas}")
    creadas
  end
end
