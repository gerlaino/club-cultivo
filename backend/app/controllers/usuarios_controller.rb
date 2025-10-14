class ClubUsersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_user, only: [:show, :update, :destroy, :reset_password]

  # GET /usuarios
  def index
    q   = params[:query].to_s.strip.downcase
    rel = User.where(club_id: current_user.club_id)

    if q.present?
      rel = rel.where(
        "lower(first_name) LIKE :q OR lower(last_name) LIKE :q OR lower(email) LIKE :q",
        q: "%#{q}%"
      )
    end

    users = rel.order("created_at DESC")
    render json: { data: users.as_json(only: [:id, :email, :first_name, :last_name, :role, :created_at, :updated_at]) }
  end

  # GET /usuarios/:id
  def show
    render json: { data: @user.as_json(only: [:id, :email, :first_name, :last_name, :role, :created_at, :updated_at]) }
  end

  # POST /usuarios
  def create
    user = User.new(user_params)
    user.club_id = current_user.club_id
    # password temporal para crear el usuario
    tmp_password = SecureRandom.base64(12)
    user.password = tmp_password
    user.password_confirmation = tmp_password

    if user.save
      # dispara mail de reset para que el usuario defina su password
      user.send_reset_password_instructions
      render json: { data: user.as_json(only: [:id, :email, :first_name, :last_name, :role]) }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT/PATCH /usuarios/:id
  def update
    if @user.update(user_params)
      render json: { data: @user.as_json(only: [:id, :email, :first_name, :last_name, :role]) }
    else
      render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /usuarios/:id
  def destroy
    if @user.id == current_user.id
      return render json: { errors: ['No podés eliminarte a vos mismo.'] }, status: :unprocessable_entity
    end

    # opcional: impedir borrar super_admin si quien borra no es super_admin
    if @user.role == 'super_admin' && !current_user.super_admin?
      return render json: { errors: ['No autorizado para eliminar a un super_admin.'] }, status: :forbidden
    end

    @user.destroy!
    head :no_content
  end


  # POST /usuarios/:id/reset_password
  def reset_password
    @user.send_reset_password_instructions
    head :no_content
  end

  private

  def set_user
    @user = User.where(club_id: current_user.club_id).find(params[:id])
  end

  def require_admin!
    head :forbidden unless current_user.admin? || current_user.super_admin?
  end

  # Solo campos que EXISTEN en tu schema
  def user_params
    params.require(:user).permit(:email, :first_name, :last_name, :role)
  end
end


