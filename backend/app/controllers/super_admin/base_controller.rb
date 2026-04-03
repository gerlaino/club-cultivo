class SuperAdmin::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :require_super_admin!

  private

  def require_super_admin!
    render json: { error: 'No autorizado' }, status: :forbidden unless current_user.super_admin?
  end
end