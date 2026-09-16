# Mails de ACCESO a la plataforma: salen por la casilla de la PLATAFORMA (`Club::PLATFORM_FROM`
# y el SMTP del entorno), no por la de la organización. Es a propósito: quien no puede entrar
# no puede conectar su correo, y el admin sin contraseña es exactamente ese caso.
class AccesoMailer < ApplicationMailer
  # El link para elegir una contraseña nueva. Va a `email_real`, nunca al login inventado.
  def restablecer_contrasena(user:, token:)
    @user   = user
    @club   = user.club
    @link   = "#{App.base_url}/restablecer?token=#{token}"
    @horas  = (Devise.reset_password_within / 1.hour).to_i
    adjuntar_logo(@club) if @club
    mail(to: user.email_real, subject: 'Elegí una contraseña nueva — Cultivo Espacial')
  end

  # El plan vence (en `dias` días) o venció hoy (`dias == 0`). Va al admin de la organización.
  def plan_vence(user:, club:, dias:)
    @user  = user
    @club  = club
    @dias  = dias
    @fecha = club.plan_activo_hasta.strftime('%d/%m/%Y')
    adjuntar_logo(club)
    asunto = dias.zero? ? "El plan de #{club.name} vence hoy" : "El plan de #{club.name} vence en #{dias} días"
    mail(to: user.email_real, subject: "#{asunto} — Cultivo Espacial")
  end
end
