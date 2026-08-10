module Public
  class BaseController < ApplicationController
    # No requiere autenticación
    skip_before_action :authenticate_user!, raise: false
    # Público: el club se resuelve por token/slug, no por el del usuario. Un super admin
    # logueado abriendo un carnet o un pasaporte no tiene por qué recibir el aviso de contexto.
    skip_before_action :block_super_admin_sin_contexto!, raise: false

    # Blindaje de tenant (prep TEN-01c). Cada controller público declara cómo resuelve
    # su tenant:
    #  - :club  → todo el request corre con el tenant de current_club. Para vistas de un
    #             club (club, eventos, galería, genéticas, noticias): un query suelto queda
    #             igual scopeado y, con require_tenant=true, no explota.
    #  - :token → el recurso se busca por un token GLOBAL (carnet, dispensa, QR de planta/
    #             stock): la búsqueda es inherentemente cross-club, así que corre sin tenant
    #             y el scoping baja por las asociaciones del recurso resuelto (FK).
    # Hoy (require_tenant=false y sin usuario → tenant nil) es un no-op; deja la base lista
    # para el flip sin cambiar comportamiento.
    class_attribute :public_tenant_mode, default: :club, instance_writer: false

    around_action :con_tenant_publico

    private

    def con_tenant_publico
      if public_tenant_mode == :token || current_club.nil?
        ActsAsTenant.without_tenant { yield }
      else
        ActsAsTenant.with_tenant(current_club) { yield }
      end
    end

    # Helper para obtener el club
    def current_club
      @current_club ||= Club.first # Por ahora club único
      # TODO: Implementar lógica según subdomain o parámetro cuando tengas múltiples clubs
    end
  end
end