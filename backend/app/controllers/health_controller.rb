class HealthController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    render json: { ok: true, time: Time.current }
  end
end
