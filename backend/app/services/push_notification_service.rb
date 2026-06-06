class PushNotificationService
  def self.notify_user_async(user, title:, body:, url: '/')
    return unless user

    user.push_subscriptions.active.each do |sub|
      PushNotificationJob.perform_later(sub.id, title: title, body: body, url: url)
    end
  end

  def self.notify_admins_async(club, title:, body:, url: '/')
    club.users.where(role: 'admin').each do |admin|
      notify_user_async(admin, title: title, body: body, url: url)
    end
  end
end
