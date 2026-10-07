# Cada pedido a la API suma su tiempo a `metricas_respuesta` (panel de Estado: «lo más lento de
# hoy»). En los specs no: cada request escribiría una fila y los specs que cuentan filas de otras
# tablas no se enteran, pero los que miden la cantidad de consultas sí.
unless Rails.env.test?
  ActiveSupport::Notifications.subscribe('process_action.action_controller') do |*args|
    evento = ActiveSupport::Notifications::Event.new(*args)
    p = evento.payload
    next if p[:controller].blank?

    Metricas::Respuesta.registrar(
      endpoint: "#{p[:controller]}##{p[:action]}",
      ms:       evento.duration,
      club_id:  ActsAsTenant.current_tenant&.id
    )
  end
end
