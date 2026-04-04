class PreferencesController < ApplicationController
  include Rails.application.routes.url_helpers
  before_action :authenticate_user!
  before_action :require_club_user!
  before_action :set_club

  def show
    authorize @club, :show?
    render json: serialize(@club)
  end

  def update
    authorize @club, :update?

    if ActiveModel::Type::Boolean.new.cast(params[:purge_logo])
      @club.logo.purge if @club.logo.attached?
    end

    if @club.update(club_params)
      render json: serialize(@club)
    else
      render json: { errors: @club.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def upload_logo
    authorize @club, :upload_logo?
    unless params[:logo].present?
      return render json: { errors: ["Archivo no recibido"] }, status: :bad_request
    end

    @club.logo.purge if @club.logo.attached?
    @club.logo.attach(params[:logo])

    if @club.logo.attached?
      render json: serialize(@club)
    else
      render json: { errors: ["No se pudo adjuntar el logo"] }, status: :unprocessable_entity
    end
  end

  private

  def require_club_user!
    return head :no_content if current_user.super_admin?
  end

  def set_club
    @club = current_user.club
  end

  def club_params
    params.require(:club).permit(
      :name, :legal_name, :email, :phone, :website,
      :address, :city, :state, :timezone, :theme_primary,
      :cuit, :numero_igj, :numero_resolucion_reprocann,
      :fecha_resolucion_reprocann, :tipo_organizacion
    )
  end

  def serialize(club)
    {
      id:                           club.id,
      name:                         club.name,
      legal_name:                   club.legal_name,
      email:                        club.email,
      phone:                        club.phone,
      website:                      club.website,
      address:                      club.address,
      city:                         club.city,
      state:                        club.state,
      timezone:                     club.timezone,
      theme_primary:                club.theme_primary,
      cuit:                         club.cuit,
      numero_igj:                   club.numero_igj,
      numero_resolucion_reprocann:  club.numero_resolucion_reprocann,
      fecha_resolucion_reprocann:   club.fecha_resolucion_reprocann,
      tipo_organizacion:            club.tipo_organizacion,
      logo_url:                     club.logo.attached? ? url_for(club.logo) : nil
    }
  end
end
