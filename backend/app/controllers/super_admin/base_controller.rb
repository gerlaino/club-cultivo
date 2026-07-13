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

    def current_club
      @current_club ||= begin
                          slug = params[:club_slug] || request.subdomain.presence
                          slug.present? ? Club.find_by(slug: slug) : Club.first
                        end
    end
  end
end
