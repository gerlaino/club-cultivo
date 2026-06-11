class AlertasInternasChannel < ApplicationCable::Channel
  def subscribed
    stream_from "alertas_club_#{current_user.club_id}"
    stream_from "alertas_user_#{current_user.id}"
  end

  def unsubscribed; end
end
