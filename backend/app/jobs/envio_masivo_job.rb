# Manda un envío masivo, UN MAIL POR DESTINATARIO.
#
# Va a cola y no sincrónico —al revés que el mail suelto de la ficha— por dos razones: 300
# envíos no entran en el tiempo de un request, y hay que espaciarlos para no chocar contra el
# límite por minuto de la casilla.
#
# Cada destinatario se rescata por separado: que uno rebote (dirección mal escrita, buzón lleno)
# no puede cortar los 299 que faltan. Lo que falló queda anotado con su error.
class EnvioMasivoJob < ApplicationJob
  queue_as :default

  # Respiro entre mails. Gmail corta las ráfagas antes que el tope diario, y un envío que se
  # traba a la mitad es peor que uno que tarda dos minutos más.
  PAUSA = 0.4

  def perform(envio_id)
    envio = ActsAsTenant.without_tenant { EnvioMasivo.find_by(id: envio_id) }
    return if envio.nil? || !envio.en_curso?

    ActsAsTenant.with_tenant(envio.club) do
      envio.update!(estado: 'enviando', comenzado_at: Time.current)

      envio.destinatarios.each do |d|
        enviar_uno(envio, d)
        sleep PAUSA
      end

      envio.update!(
        estado: envio.enviados.positive? ? 'completado' : 'fallido',
        terminado_at: Time.current
      )
    end
  end

  private

  def enviar_uno(envio, dest)
    email = dest['email'].to_s.strip
    return envio.registrar!(email, ok: false, error: 'Sin dirección de correo') if email.blank?

    if dest['paciente_id'].present?
      enviar_a_paciente(envio, dest, email)
    else
      enviar_libre(envio, dest, email)
    end
  rescue => e
    # Nunca propaga: un destinatario que revienta no puede tumbar el envío entero.
    envio.registrar!(email, ok: false, error: e.message)
  end

  # A un paciente se le manda con `Correo::EnviarAPaciente` para que quede en SU historial: el
  # día que pregunte "¿ustedes me avisaron?", la respuesta está en su ficha.
  def enviar_a_paciente(envio, dest, email)
    paciente = Paciente.find_by(id: dest['paciente_id'])
    return envio.registrar!(email, ok: false, error: 'El paciente ya no está') if paciente.nil?

    r = Correo::EnviarAPaciente.call(
      paciente:  paciente,
      usuario:   envio.user,
      # El texto viene YA resuelto por destinatario: {{nombre}} es distinto para cada uno.
      asunto:    dest['asunto'].presence || envio.asunto,
      cuerpo:    dest['cuerpo'].presence || envio.cuerpo,
      tipo:      'personalizado',
      plantilla: envio.plantilla_mail
    )
    envio.registrar!(email, ok: r.ok?, error: r.error)
  end

  # A una dirección suelta (un proveedor) no hay historial que actualizar: el rastro queda en
  # el envío.
  def enviar_libre(envio, _dest, email)
    unless envio.club.smtp_configured?
      return envio.registrar!(email, ok: false, error: 'La organización no tiene casilla conectada')
    end

    PacienteMailer.libre(
      club: envio.club, remitente: envio.user, to: email,
      asunto: envio.asunto, cuerpo: envio.cuerpo
    ).deliver_now
    envio.registrar!(email, ok: true)
  end
end
