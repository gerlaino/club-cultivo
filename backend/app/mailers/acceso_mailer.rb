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

  # Aviso de que la contraseña cambió. Como el perfil ya no pide la actual para cambiarla, esto es
  # lo que le avisa al dueño si no fue él (y le dice cómo recuperarla).
  def contrasena_cambiada(user:)
    @user   = user
    @club   = user.club
    @cuando = Time.current.in_time_zone('America/Argentina/Buenos_Aires').strftime('%d/%m/%Y a las %H:%M')
    @link   = "#{App.base_url}/olvide-contrasena"
    adjuntar_logo(@club) if @club
    mail(to: user.email_real, subject: 'Tu contraseña cambió — Cultivo Espacial')
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

  # Autoregistro de uso personal: el link para confirmar el mail. La cuenta YA anda; esto sólo
  # evita que se pause a los `RegistroPersonal::GRACIA` días.
  def confirmar_mail(registro:, token:)
    @user  = registro.user
    @link  = "#{App.base_url}/registro/confirmar?token=#{token}"
    @dias  = (RegistroPersonal::GRACIA / 1.day).to_i
    mail(to: registro.email, subject: 'Confirmá tu mail — Cultivo Espacial')
  end

  # Alguien dejó una consulta en /bienvenida. Va a cada super admin por separado (nunca `To:`
  # múltiple), y es un aviso: la consulta ya está guardada en el panel.
  def nueva_consulta(solicitud:, para:)
    @s = solicitud
    @link = "#{App.base_url}/super-admin/consultas"
    mail(to: para, reply_to: solicitud.email,
         subject: "Consulta nueva (#{solicitud.tipo_label}): #{solicitud.nombre} — Cultivo Espacial")
  end

  # El acuse para quien escribió, con su código de trámite. Para el arrepentimiento es lo que pide
  # la Res. SCI 424/2020; para el resto, que sepa que llegó.
  def acuse_consulta(solicitud:)
    @s = solicitud
    mail(to: solicitud.email, subject: "Recibimos tu #{solicitud.tipo == 'baja' ? 'pedido' : 'consulta'} (#{solicitud.codigo}) — Cultivo Espacial")
  end

  # La respuesta del super admin a una consulta de /bienvenida. Sale por la casilla de la plataforma;
  # si la persona contesta, le llega a esa casilla.
  def respuesta_consulta(respuesta:)
    @r = respuesta
    @s = respuesta.solicitud_contacto
    mail(to: @s.email, subject: "Re: tu #{@s.tipo == 'baja' ? 'pedido' : 'consulta'} (#{@s.codigo}) — Cultivo Espacial")
  end
end
