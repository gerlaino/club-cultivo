class DetectarAlertasJob < ApplicationJob
  queue_as :default

  def perform(club_id = nil)
    clubs = club_id ? Club.where(id: club_id) : Club.all
    clubs.find_each do |club|
      AlertaDetectorService.new(club).detectar!
    rescue => e
      Rails.logger.error "DetectarAlertasJob club #{club.id}: #{e.class}: #{e.message}"
    end
  end
end
