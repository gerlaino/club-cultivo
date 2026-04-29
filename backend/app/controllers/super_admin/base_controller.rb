module SuperAdmin
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_super_admin!

    private

    def require_super_admin!
      unless current_user&.super_admin?
        render json: { error: 'Forbidden — super_admin only' }, status: :forbidden
      end
    end

    def current_club
      @current_club ||= begin
                          slug = params[:club_slug] || request.subdomain.presence
                          slug.present? ? Club.find_by(slug: slug) : Club.first
                        end
    end
  end
end
