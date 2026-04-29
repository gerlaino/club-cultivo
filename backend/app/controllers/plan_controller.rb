# backend/app/controllers/plan_controller.rb
class PlanController < ApplicationController
  before_action :authenticate_user!

  # GET /plan
  def show
    return render json: { plan: nil, super_admin: true } if current_user.super_admin?
    return render json: { plan: nil, sin_club: true }   if current_user.club.nil?
    enforcer = PlanEnforcer.new(current_user.club)
    render json: enforcer.info
  end
end