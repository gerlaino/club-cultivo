class MeController < ApplicationController
  before_action :authenticate_user!
  def show
    render json: { id: current_user.id, email: current_user.email, role: current_user.role, club_id: current_user.club_id }
  end
end
