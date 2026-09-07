class PushNotificationService
  def self.notify_user_async(user, title:, body:, url: '/')
    return unless user

    user.push_subscriptions.active.each do |sub|
      PushNotificationJob.perform_later(sub.id, title: title, body: body, url: url)
    end
  end

  def self.notify_admins_async(club, title:, body:, url: '/')
    notify_roles_async(club, 'admin', title: title, body: body, url: url)
  end

  # A quien corresponda: administración es admin Y supervisor, y hay avisos —una reposición
  # pedida desde el mostrador— que le sirven a los dos. Una sola implementación, para que no se
  # arme una lista de usuarios por cada aviso nuevo.
  def self.notify_roles_async(club, *roles, title:, body:, url: '/')
    club.users.where(role: roles.flatten).each do |u|
      notify_user_async(u, title: title, body: body, url: url)
    end
  end
end
