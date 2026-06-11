class StocksChannel < ApplicationCable::Channel
  def subscribed
    stream_from "stocks_club_#{current_user.club_id}"
  end

  def unsubscribed; end
end
