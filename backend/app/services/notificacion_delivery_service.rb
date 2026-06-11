class NotificacionDeliveryService
  def initialize(dispensacion)
    @d    = dispensacion
    @club = dispensacion.club || dispensacion.sede&.club
  end

  def notificar_despacho
    mensaje = "Hola #{nombre_destinatario}, tu paquete #{@d.codigo_paquete} está en camino. Pronto llegará a #{@d.direccion_envio}. — #{@club&.name}"
    enviar(mensaje)
  end

  def notificar_entrega
    mensaje = "Hola #{nombre_destinatario}, tu paquete #{@d.codigo_paquete} fue entregado exitosamente. ¡Gracias! — #{@club&.name}"
    enviar(mensaje)
  end

  private

  def enviar(mensaje)
    telefono = @d.contacto_telefono.presence || @d.paciente&.telefono.presence

    if @club&.twilio_configurado? && telefono.present?
      enviar_whatsapp(mensaje, telefono)
    else
      enviar_email(mensaje)
    end
  rescue => e
    Rails.logger.error("[NotificacionDelivery] Error: #{e.message}")
  end

  def enviar_whatsapp(mensaje, telefono)
    numero_destino = normalizar_telefono(telefono)
    return unless numero_destino

    client = Twilio::REST::Client.new(@club.twilio_account_sid, @club.twilio_auth_token)
    client.messages.create(
      from: @club.twilio_whatsapp_from,
      to:   "whatsapp:#{numero_destino}",
      body: mensaje
    )
  end

  def enviar_email(mensaje)
    email = @d.paciente&.email.presence
    return unless email.present?

    NotificacionesMailer.notificacion_delivery(
      email:   email,
      nombre:  nombre_destinatario,
      mensaje: mensaje,
      club:    @club
    ).deliver_later
  end

  def nombre_destinatario
    @d.contacto_nombre.presence || "#{@d.paciente&.nombre} #{@d.paciente&.apellido}".strip.presence || "Estimado/a"
  end

  def normalizar_telefono(tel)
    # Limpia el número y agrega prefijo AR si no tiene código de país
    limpio = tel.to_s.gsub(/[^0-9+]/, '')
    return limpio if limpio.start_with?('+')
    limpio.start_with?('0') ? "+54#{limpio[1..]}" : "+54#{limpio}"
  end
end
