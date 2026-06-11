class PushSubscriptionsController < ApplicationController
  before_action :authenticate_user!

  def create
    sub = current_user.push_subscriptions.find_or_initialize_by(endpoint: params[:endpoint])
    sub.assign_attributes(
      club:        current_user.club,
      p256dh_key:  params[:p256dh_key],
      auth_key:    params[:auth_key],
      device_name: params[:device_name],
      active:      true
    )
    if sub.save
      head :created
    else
      render json: { errors: sub.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    sub = current_user.push_subscriptions.find_by(endpoint: params[:endpoint])
    sub&.destroy
    head :no_content
  end
end
