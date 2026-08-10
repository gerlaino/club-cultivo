module SuperAdmin
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_super_admin!

    # El super_admin opera cross-club a propósito (set_tenant lo deja sin tenant). Con
    # require_tenant=true (TEN-01c) un query a un modelo tenant explotaría; lo corremos
    # explícitamente sin tenant. Hoy es no-op (ya venía sin tenant). El scoping por club
    # de cada action sigue siendo manual (current_club / asociaciones).
    around_action :sin_tenant_super_admin

    private

    def sin_tenant_super_admin
      ActsAsTenant.without_tenant { yield }
    end

    def require_super_admin!
      unless current_user&.super_admin?
        render json: { error: 'Forbidden — super_admin only' }, status: :forbidden
      end
    end

    # Resuelve el club por slug cuando la ruta lo trae. NO tiene fallback: la versión anterior
    # caía a `Club.first` si no venía slug, así que una action que se olvidara de pasarlo
    # operaba en silencio sobre el club 1. Sin slug no hay club, y quien lo necesite que se
    # entere con un nil en vez de trabajar sobre el equivocado.
    def current_club
      slug = params[:club_slug] || request.subdomain.presence
      return nil if slug.blank?

      @current_club ||= Club.find_by(slug: slug)
    end
  end
end
