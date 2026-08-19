module Portal
  # Lo que la organización le muestra a SUS pacientes: catálogo, novedades, eventos, galería.
  #
  # Antes esto vivía bajo `Public::` y no pedía login. Dos problemas, los dos serios:
  #
  #   1. `Public::BaseController#current_club` era `Club.first` con un TODO. La web pública
  #      multi-club nunca funcionó: servía siempre el club número uno, y cualquiera sin cuenta
  #      leía su catálogo entero sabiendo la URL. Acá el club sale de `current_user`, así que es
  #      correcto y multi-tenant por construcción, sin resolver nada por slug.
  #   2. Una organización de REPROCANN con su catálogo indexable se expone sin necesidad. Que
  #      esto viva detrás del login del miembro es la opción conservadora, y además es lo que
  #      vuelve al módulo algo que la organización PERCIBE y puede pagar.
  #
  # Siguen públicos —a propósito— el carnet (`/c/:token`) y el pasaporte de dispensa
  # (`/d/:token`): son links que la persona entrega deliberadamente y funcionan sin cuenta.
  class BaseController < ApplicationController
    # Primero la sesión: sin esto, sin usuario caía en el chequeo de módulo y contestaba 403
    # —parece bien y no lo está: el 403 dice "no te alcanza el permiso" cuando lo que falta es
    # entrar, y `current_club` se resuelve sobre un usuario que no existe.
    before_action :authenticate_user!
    before_action -> { require_feature!(:vista_paciente) }
    before_action :require_acceso_paciente!

    private

    # El paciente ve lo suyo; el admin entra para poder PREVISUALIZAR lo que va a ver su gente
    # antes de prenderlo. Nadie más: esto no es una vista de operación.
    ROLES = %w[paciente admin].freeze

    def require_acceso_paciente!
      return if current_user.super_admin?
      return if ROLES.include?(current_user.role.to_s)

      render json: { error: 'Esta sección es del área de pacientes' }, status: :forbidden
    end

    # De qué organización se habla. Sale del usuario, no de un slug en la URL.
    def current_club = current_user.club
  end
end
