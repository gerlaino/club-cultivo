# backend/app/controllers/plan_controller.rb
class PlanController < ApplicationController
  before_action :authenticate_user!

  # GET /plan
  def show
    enforcer = PlanEnforcer.new(current_user.club)
    render json: enforcer.info
  end
end