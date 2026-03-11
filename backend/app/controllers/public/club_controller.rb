module Public
  class ClubController < BaseController
    def show
      club = current_club

      return render json: { error: 'Club no encontrado' }, status: :not_found unless club

      render json: {
        id: club.id,
        name: club.name,
        legal_name: club.legal_name,
        phone: club.phone,
        email: club.email,
        website: club.website,
        address: club.address,
        city: club.city,
        state: club.state,
        country: club.country,
        timezone: club.timezone,
        theme_primary: club.theme_primary,
        logo_url: club.logo.attached? ? url_for(club.logo) : nil
      }
    end
  end
end