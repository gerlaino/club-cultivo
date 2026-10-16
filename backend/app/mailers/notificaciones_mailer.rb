class NotificacionesMailer < ApplicationMailer
  # UN MAIL POR DESTINATARIO (15-oct-2026). Los avisos internos salían con todos los admins en el
  # mismo `To:`: cada uno veía la casilla de los demás. Ahora cada acción recibe UNA persona
  # (`para:`) y el que avisa recorre la lista. Si a uno no le sale, a los demás sí.
  def self.a_cada(usuarios, accion, **args)
    usuarios.each do |u|
      public_send(accion, para: u, **args).deliver_now
    rescue => e
      Rails.logger.warn("[#{accion}] no salió a #{u.id}: #{e.message}")
    end
  end

  def self.admins_de(club) = club.users.where(role: 'admin').where.not(email: nil).to_a

  # Enviado a los admins del club cuando hay pacientes con REPROCANN vencido o por vencer
  def resumen_reprocann(para:, club:, vencidos:, por_vencer:)
    @club        = club
    @vencidos    = vencidos
    @por_vencer  = por_vencer
    @total       = vencidos.size + por_vencer.sum { |_, lista| lista.size }

    return if para.email_notificacion.blank?

    mail_para_club(@club,
      to:      para.email_notificacion,
      subject: "[#{club.name}] REPROCANN — #{@total} paciente#{@total == 1 ? '' : 's'} requieren atención")
  end

  # Resumen de indicaciones médicas vencidas o por vencer — enviada a admin + médico del club
  def resumen_indicaciones(para:, club:, vencidas:, por_vencer:)
    @club       = club
    @vencidas   = vencidas
    @por_vencer = por_vencer
    @total      = vencidas.size + por_vencer.sum { |_, lista| lista.size }

    return if para.email_notificacion.blank?

    mail_para_club(@club,
      to:      para.email_notificacion,
      subject: "[#{club.name}] Indicaciones médicas — #{@total} requieren atención")
  end

  # Informe semestral automático — enviado a admins del club
  def informe_semestral(para:, club:, datos:, modo:, anio:, semestre:)
    @club      = club
    @datos     = datos
    @modo      = modo
    @anio      = anio
    @semestre  = semestre

    return if para.email_notificacion.blank?

    asunto = if modo == :recordatorio
      "[#{club.name}] Recordatorio: informe semestral vence en 30 días (#{semestre}° sem. #{anio})"
    else
      "[#{club.name}] Informe semestral #{semestre}° semestre #{anio}"
    end

    mail_para_club(@club, to: para.email_notificacion, subject: asunto)
  end

  # Notificación de delivery al paciente (fallback cuando no hay WhatsApp configurado)
  def notificacion_delivery(email:, nombre:, mensaje:, club:)
    @nombre  = nombre
    @mensaje = mensaje
    @club    = club

    mail_para_club(@club, to: email, subject: "#{club&.name} — Actualización de tu paquete")
  end

  # Aviso directo al socio cuando su REPROCANN está por vencer
  def aviso_reprocann_paciente(paciente:, dias_restantes:, club:)
    @paciente       = paciente
    @dias_restantes = dias_restantes
    @club           = club

    return unless paciente.email.present?

    mail_para_club(@club,
      to:      paciente.email,
      subject: "#{club.name} — Tu autorización REPROCANN vence en #{dias_restantes} día#{dias_restantes == 1 ? '' : 's'}")
  end

  # Resumen de una ruta de entregas finalizada — enviado a los admins del club.
  def resumen_ruta(para:, club:, delivery:, entregados:, fallidos:, caja_efectivo: 0)
    @club          = club
    @delivery      = delivery
    @entregados    = entregados
    @fallidos      = fallidos
    @caja_efectivo = caja_efectivo.to_d

    return if para.email_notificacion.blank?

    mail_para_club(@club,
      to:      para.email_notificacion,
      subject: "[#{club.name}] Ruta de entregas finalizada — #{entregados.size} entregado#{'s' if entregados.size != 1}, #{fallidos.size} fallido#{'s' if fallidos.size != 1}")
  end

  # Alerta de stock bajo — enviada al admin
  def stock_bajo(para:, club:, stocks_data:)
    @club        = club
    @stocks_data = stocks_data

    return if para.email_notificacion.blank?

    mail_para_club(@club,
      to:      para.email_notificacion,
      subject: "[#{club.name}] Alerta: stock bajo en dispensario")
  end

  # La merma del mostrador se salió del patrón de esta organización.
  #
  # NO acusa a nadie: la merma es inevitable y el mail dice "acá cambió algo, andá a mirar". El
  # asunto lleva la sede porque con varias, saber cuál es la mitad del aviso.
  def merma_mostrador(para:, club:, sede:, pct:, pct_previo:, ars:)
    @club       = club
    @sede       = sede
    @pct        = pct
    @pct_previo = pct_previo
    @ars        = ars

    return if para.email_notificacion.blank?

    mail_para_club(@club,
      to:      para.email_notificacion,
      subject: "[#{club.name}] La merma del mostrador de #{sede} subió a #{pct}%")
  end
end
