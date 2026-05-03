class JwtDenylistCleanupJob < ApplicationJob
  queue_as :default

  def perform
    JwtDenylist.expired.delete_all
  end
end
