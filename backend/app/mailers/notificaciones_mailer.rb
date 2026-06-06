class NotificacionesMailer < ApplicationMailer
  default from: -> { ENV.fetch('MAIL_FROM', 'noreply@clubcultivo.app') }

  # Enviado a los admins del club cuando hay pacientes con REPROCANN vencido o por vencer
  def resumen_reprocann(club:, vencidos:, por_vencer:)
    @club        = club
    @vencidos    = vencidos
    @por_vencer  = por_vencer
    @total       = vencidos.size + por_vencer.sum { |_, lista| lista.size }

    admins = club.users.where(role: 'admin').where.not(email: nil)
    return if admins.none?

    mail(
      to:      admins.pluck(:email),
      subject: "[#{club.name}] REPROCANN — #{@total} paciente#{@total == 1 ? '' : 's'} requieren atención"
    )
  end

  # Resumen de indicaciones médicas vencidas o por vencer — enviada a admin + médico del club
  def resumen_indicaciones(club:, vencidas:, por_vencer:)
    @club       = club
    @vencidas   = vencidas
    @por_vencer = por_vencer
    @total      = vencidas.size + por_vencer.sum { |_, lista| lista.size }

    destinatarios = club.users.where(role: %w[admin medico]).where.not(email: nil).pluck(:email).uniq
    return if destinatarios.empty?

    mail(
      to:      destinatarios,
      subject: "[#{club.name}] Indicaciones médicas — #{@total} requieren atención"
    )
  end

  # Informe semestral automático — enviado a admins del club
  def informe_semestral(club:, datos:, modo:, anio:, semestre:)
    @club      = club
    @datos     = datos
    @modo      = modo
    @anio      = anio
    @semestre  = semestre

    admins = club.users.where(role: 'admin').where.not(email: nil)
    return if admins.none?

    asunto = if modo == :recordatorio
      "[#{club.name}] Recordatorio: informe semestral vence en 30 días (#{semestre}° sem. #{anio})"
    else
      "[#{club.name}] Informe semestral #{semestre}° semestre #{anio}"
    end

    mail(to: admins.pluck(:email), subject: asunto)
  end

  # Notificación de delivery al paciente (fallback cuando no hay WhatsApp configurado)
  def notificacion_delivery(email:, nombre:, mensaje:, club:)
    @nombre  = nombre
    @mensaje = mensaje
    @club    = club

    from_addr = club&.smtp_configured? ? "#{club.smtp_from_name.presence || club.name} <#{club.smtp_from.presence || club.smtp_user}>" : default_params[:from]

    mail(
      to:      email,
      from:    from_addr,
      subject: "#{club&.name} — Actualización de tu paquete"
    )
  end

  # Alerta de stock bajo — enviada al admin
  def stock_bajo(club:, stocks_data:)
    @club        = club
    @stocks_data = stocks_data

    admins = club.users.where(role: 'admin').where.not(email: nil)
    return if admins.none?

    mail(
      to:      admins.pluck(:email),
      subject: "[#{club.name}] Alerta: stock bajo en dispensario"
    )
  end
end
