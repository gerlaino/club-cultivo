# Manda la respuesta a una consulta y anota si salió (`enviada_at`) o por qué no (`error`, y el job
# se reintenta). La bandeja del super admin muestra cuál de las dos pasó: una respuesta que no salió
# no puede verse igual que una que sí.
class EnviarRespuestaConsultaJob < ApplicationJob
  queue_as :default

  def perform(respuesta_id)
    r = ConsultaRespuesta.find_by(id: respuesta_id)
    return if r.nil? || r.enviada_at

    AccesoMailer.respuesta_consulta(respuesta: r).deliver_now
    r.update!(enviada_at: Time.current, error: nil)
  rescue StandardError => e
    r&.update_columns(error: e.message.to_s.first(250))
    raise
  end
end
