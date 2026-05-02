class BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :check_club_activo!
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

  def check_club_activo!
    return if current_user&.super_admin?
    return unless current_user&.club_id.present?
    if current_user.club.nil? || current_user.club.eliminado?
      render json: { error: 'Club inactivo o eliminado' }, status: :forbidden
    end
  end
end
