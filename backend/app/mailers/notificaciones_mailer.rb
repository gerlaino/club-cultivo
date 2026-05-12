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
