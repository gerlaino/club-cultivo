class AlertasInternasChannel < ApplicationCable::Channel
  def subscribed
    user = find_verified_user
    return reject unless user

    stream_from "alertas_club_#{user.club_id}"
    stream_from "alertas_user_#{user.id}"
  end

  def unsubscribed; end

  private

  def find_verified_user
    token = request.params[:token] || request.headers['Authorization']&.split(' ')&.last
    return nil unless token

    payload = JWT.decode(token, Rails.application.credentials.devise_jwt_secret_key!, true,
                         algorithms: ['HS256']).first
    User.find_by(id: payload['sub'])
  rescue JWT::DecodeError, ActiveRecord::RecordNotFound
    nil
  end
end
