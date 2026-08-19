module Portal
  class ClubController < BaseController
    def show
      club = current_club

      return render json: { error: 'Organización no encontrada' }, status: :not_found unless club

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
        # Lo que el admin escribe en Configuración → Portal del paciente. Estaba guardado y no lo
        # mostraba nadie: el endpoint devolvía sólo los datos de contacto.
        descripcion:       club.descripcion_web,
        horarios_atencion: club.horarios_atencion,
        instagram_url:     club.instagram_url,
        facebook_url:      club.facebook_url,
        whatsapp:          club.whatsapp,
        logo_url: club.logo.attached? ? url_for(club.logo) : nil
      }
    end
  end
end