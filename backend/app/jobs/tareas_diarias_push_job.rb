class TareasDiariasPushJob < ApplicationJob
  queue_as :medium

  def perform
    return unless ENV['VAPID_PUBLIC_KEY'].present?

    Club.activos.each do |club|
      ActsAsTenant.with_tenant(club) do
        tareas_hoy = club.tareas
                         .activas
                         .de_hoy
                         .where.not(asignada_a_id: nil)
                         .includes(:asignada_a)

        tareas_hoy.group_by(&:asignada_a).each do |usuario, tareas|
          next unless usuario

          count = tareas.size
          resumen = tareas.first(2).map(&:titulo).join(' · ')
          titulo = count == 1 ? "1 tarea para hoy" : "#{count} tareas para hoy"

          PushNotificationService.notify_user_async(
            usuario,
            title: titulo,
            body:  resumen,
            url:   '/m/cultivador/tareas'
          )
        end
      end
    end
  end
end
