module Medico
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_medico!
    before_action -> { require_feature!(:medico) }

    private

    def require_medico!
      unless current_user.medico? || current_user.admin? || current_user.super_admin?
        render json: { error: 'Acceso restringido al rol médico' }, status: :forbidden
      end
    end

    def club
      @club ||= current_user.club
    end
  end
end
