module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
      reject_unauthorized_connection unless current_user
    end

    private

    def find_verified_user
      # request es accesible aquí (en Connection), no en los channels
      token = request.params[:token] ||
              request.headers['Authorization']&.split(' ')&.last
      return nil unless token

      payload = JWT.decode(
        token,
        Rails.application.credentials.devise_jwt_secret_key!,
        true,
        algorithms: ['HS256']
      ).first
      User.find_by(id: payload['sub'])
    rescue JWT::DecodeError, ActiveRecord::RecordNotFound
      nil
    end
  end
end
