# app/controllers/profile_controller.rb
class ProfileController < ApplicationController
  before_action :authenticate_user!

  def show
    render json: { data: serialize_user(current_user) }
  end

  def update
    if current_user.update(profile_params)
      render json: { data: serialize_user(current_user) }, status: :ok
    else
      render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def password
    unless current_user.valid_password?(params.dig(:user, :current_password).to_s)
      return render json: { errors: ["La contraseña actual no es correcta"] }, status: :unprocessable_entity
    end
    if current_user.update(password_params)
      render json: { message: "Contraseña actualizada" }, status: :ok
    else
      render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def avatar
    if params[:avatar].present?
      current_user.avatar.attach(params[:avatar])
      if current_user.valid?
        render json: { data: serialize_user(current_user) }, status: :ok
      else
        render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { errors: ["Archivo no recibido"] }, status: :bad_request
    end
  end

  private

  def profile_params
    params.require(:user).permit(:first_name, :last_name, :dni, :birth_date, :email, :phone)
  end

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end

  def serialize_user(u)
    {
      id: u.id,
      email: u.email,
      role: u.role,
      club_id: u.club_id,
      first_name: u.first_name,
      last_name: u.last_name,
      dni: u.dni,
      birth_date: u.birth_date,
      phone: u.phone,
      avatar_url: u.avatar.attached? ? url_for(u.avatar) : nil
    }
  end
end
