# app/controllers/clubs_controller.rb
class ClubsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  # GET /preferences
  def show
    render json: { data: club_payload(current_user.club) }
  end

  # PUT /preferences
  def update
    club = current_user.club

    # Purga de logo
    club.logo.purge_later if params[:purge_logo].present? && club.logo.attached?

    # Subida de logo (multipart)
    club.logo.attach(params[:logo]) if params[:logo].present?

    # Mapeo: del payload del front a columnas REALES de la DB
    p = club_params

    club.assign_attributes(
      name:        p[:name],
      legal_name:  p[:legal_name],
      website:     p[:website],
      # columnas reales:
      email:       p[:contact_email],
      phone:       p[:contact_phone],
      address:     p[:address_line1],
      city:        p[:city],
      state:       p[:province],
      country:     p[:country],
      timezone:    p[:timezone]
    )

    if club.save
      render json: { data: club_payload(club) }
    else
      render json: { errors: club.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  # ⚠️ Permitimos los nombres que manda/espera el FRONT
  def club_params
    params.require(:club).permit(
      :name, :legal_name,
      :contact_email, :contact_phone, :website,
      :address_line1, :city, :province, :country, :timezone
    )
  end

  # Autorización sin depender de enum
  def require_admin!
    allowed = %w[admin super_admin].include?(current_user.role.to_s)
    head :forbidden unless allowed
  end

  # Respuesta: convertimos de columnas reales → nombres del FRONT
  def club_payload(club)
    {
      id:             club.id,
      name:           club.name,
      legal_name:     club.legal_name,
      contact_email:  club.email,
      contact_phone:  club.phone,
      website:        club.website,
      address_line1:  club.address,
      city:           club.city,
      province:       club.state,
      country:        club.country,
      timezone:       club.timezone,
      # Evitamos variant() para no depender de libvips/imagick
      logo_url:       club.logo.attached? ? url_for(club.logo) : nil
    }
  end
end



