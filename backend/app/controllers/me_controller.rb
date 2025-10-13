class MeController < ApplicationController
  before_action :authenticate_user!

  def show
    render json: current_user.as_json(
      only: %i[id email role club_id first_name last_name dni birthdate phone avatar_url created_at updated_at]
    )
  end
end

