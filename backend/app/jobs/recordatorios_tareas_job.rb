# Manda el push «Recordarme» de las tareas cuyo momento llegó: ese día o el día antes, a las 8
# (hora de la app). Corre cada 15 minutos; una tarea sale una sola vez (`recordatorio_enviado_at`)
# y si cambian su fecha o su recordatorio vuelve a contar. Va a quien está asignada; si no hay
# nadie asignado no hay a quién avisar y se marca como enviada para no mirarla más.
class RecordatoriosTareasJob < ApplicationJob
  queue_as :medium

  def perform
    return unless ENV['VAPID_PUBLIC_KEY'].present?

    cada_club_con do |club|
      ahora = Time.zone.now
      club.tareas.con_recordatorio_pendiente.includes(:asignada_a).find_each do |tarea|
        next unless tarea.recordatorio_pendiente?(ahora)

        if tarea.asignada_a
          cuando = tarea.recordatorio == 'dia_antes' ? 'mañana' : 'hoy'
          PushNotificationService.notify_user_async(
            tarea.asignada_a, tipo: 'recordatorio_tarea',
            title: "Recordatorio: #{tarea.titulo}",
            body:  "Es para #{cuando}#{tarea.lote ? " · #{tarea.lote.codigo}" : ''}#{tarea.sala ? " · #{tarea.sala.nombre}" : ''}",
            url:   '/tareas'
          )
        end
        tarea.update_column(:recordatorio_enviado_at, ahora)
      end
    end
  end
end
