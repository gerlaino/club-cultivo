class NotificacionDeliveryService
  def initialize(dispensacion)
    @d    = dispensacion
    # Dispensacion no tiene asociación :club directa; el club se obtiene vía la sede.
    @club = dispensacion.sede&.club
  end

  # El servicio salió a la calle (a todos menos al próximo en entregar).
  def notificar_recorrido_iniciado
    enviar("Hola #{nombre_destinatario}, el servicio de logística empezó el recorrido. Pronto llegará tu paquete #{@d.codigo_paquete}. — #{@club&.name}")
  end

  # Sos el próximo en recibir tu pedido (al primero de la ruta y a cada uno cuando pasa al frente).
  def notificar_proximo
    enviar("Hola #{nombre_destinatario}, sos el próximo en recibir tu pedido — el servicio de logística está llegando a tu domicilio con tu paquete #{@d.codigo_paquete}. — #{@club&.name}")
  end

  def notificar_entrega
    enviar("Hola #{nombre_destinatario}, tu paquete #{@d.codigo_paquete} fue entregado. ¡Gracias! — #{@club&.name}")
  end

  def notificar_fallo
    enviar("Hola #{nombre_destinatario}, tuvimos un problema con la entrega de tu paquete #{@d.codigo_paquete}. Por favor comunicate con la administración de #{@club&.name}.")
  end

  private

  def enviar(mensaje)
    telefono = @d.contacto_telefono.presence || @d.paciente&.telefono.presence

    # El add-on manda, no las credenciales. Sin este chequeo, una organización a la que se le
    # apagó WhatsApp seguía mandando mensajes —y pagándolos— mientras el Twilio siguiera
    # cargado: el interruptor del panel no controlaba nada. Cuando está apagado el aviso sale
    # por mail, que es el canal de siempre, en vez de perderse.
    if whatsapp_habilitado? && telefono.present?
      enviar_whatsapp(mensaje, telefono)
    else
      enviar_email(mensaje)
    end
  rescue => e
    Rails.logger.error("[NotificacionDelivery] Error: #{e.message}")
  end

  def whatsapp_habilitado?
    @club&.feature?('whatsapp') && @club.twilio_configurado?
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

    # Sincrónico: deliver_later dependía de Sidekiq y fallaba silencioso. Se manda en el acto;
    # si una falla, el rescue de #enviar la registra y el lote sigue (best-effort por paquete).
    NotificacionesMailer.notificacion_delivery(
      email:   email,
      nombre:  nombre_destinatario,
      mensaje: mensaje,
      club:    @club
    ).deliver_now
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
