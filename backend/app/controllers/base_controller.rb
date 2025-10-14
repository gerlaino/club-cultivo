class BaseController < ApplicationController
  before_action :authenticate_user!
  respond_to :json

  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: { code: "NOT_FOUND" } }, status: :not_found
  end

  rescue_from ActiveRecord::RecordInvalid do |e|
    render json: { error: { code: "VALIDATION_ERROR", details: e.record.errors.to_hash } }, status: :unprocessable_entity
  end

  private

  def current_club_id
    current_user.club_id
  end
end
