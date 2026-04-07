module Public
  class BaseController < ApplicationController
    include Rails.application.routes.url_helpers
    skip_before_action :authenticate_user!, raise: false

    private

    def current_club
      @current_club ||= begin
                          slug = params[:club_slug] || request.subdomain.presence
                          slug.present? ? Club.find_by(slug: slug) : Club.first
                        end
    end
  end
end