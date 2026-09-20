class PushNotificationService
  # `tipo` es una clave de `Notificaciones::Catalogo`: la persona decide en «Mi perfil» si ese
  # aviso le llega al teléfono, y acá se respeta ANTES de encolar. Sin `tipo` (una prueba desde
  # consola) se manda siempre.
  #
  # «No molestar» (22 a 8): lo que caiga ahí no se pierde, se entrega a las 8.
  def self.notify_user_async(user, title:, body:, url: '/', tipo: nil)
    return unless user
    return if tipo && !user.quiere_push?(tipo)

    hasta = user.push_diferido_hasta
    user.push_subscriptions.active.each do |sub|
      job = hasta ? PushNotificationJob.set(wait_until: hasta) : PushNotificationJob
      job.perform_later(sub.id, title: title, body: body, url: url)
    end
  end

  def self.notify_admins_async(club, title:, body:, url: '/', tipo: nil)
    notify_roles_async(club, 'admin', title: title, body: body, url: url, tipo: tipo)
  end

  # A quien corresponda: administración es admin Y supervisor, y hay avisos —una reposición
  # pedida desde el mostrador— que le sirven a los dos. Una sola implementación, para que no se
  # arme una lista de usuarios por cada aviso nuevo.
  def self.notify_roles_async(club, *roles, title:, body:, url: '/', tipo: nil)
    club.users.where(role: roles.flatten).each do |u|
      notify_user_async(u, title: title, body: body, url: url, tipo: tipo)
    end
  end
end
