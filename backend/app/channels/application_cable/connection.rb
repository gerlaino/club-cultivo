module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
      reject_unauthorized_connection unless current_user
    end

    private

    def find_verified_user
      # Prioridad: query param (mobile) → header → httpOnly cookie (web SPA)
      token = request.params[:token] ||
              request.headers['Authorization']&.split(' ')&.last ||
              request.cookies['jwt_token']
      return nil unless token

      secret = ENV['DEVISE_JWT_SECRET_KEY'] ||
               Rails.application.credentials.devise_jwt_secret_key
      return nil unless secret.present?

      payload = JWT.decode(token, secret, true, algorithms: ['HS256']).first
      User.find_by(id: payload['sub'])
    rescue JWT::DecodeError, ActiveRecord::RecordNotFound
      nil
    end
  end
end
