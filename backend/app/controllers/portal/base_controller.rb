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
    before_action :require_portal_abierto!
    before_action :require_acceso_paciente!

    private

    # Contratado Y abierto. La regla vive en `Club#portal_paciente_disponible?` y la comparte con
    # el login (`User#rol_habilitado?`): el paciente ya no llega hasta acá con el portal cerrado,
    # pero esta es la barrera de verdad —el login es la explicación en la puerta— y cubre el rato
    # entre que el admin lo cierra y el paciente vuelve a pedir algo con la sesión abierta.
    def require_portal_abierto!
      return if current_club&.portal_paciente_disponible?

      render json: { error: 'El portal de pacientes no está disponible en esta organización' },
             status: :forbidden
    end

    # Sólo el paciente. El admin que quiera ver cómo le queda esto a su gente se da de alta un
    # paciente de prueba y entra con él: es la única forma de ver lo mismo que ellos. Dejarlo
    # entrar con su propio usuario mostraba una previsualización parecida pero no igual —y una
    # previsualización que miente es peor que no tenerla.
    ROLES = %w[paciente].freeze

    def require_acceso_paciente!
      return if ROLES.include?(current_user.role.to_s)

      render json: { error: 'Esta sección es del área de pacientes' }, status: :forbidden
    end

    # De qué organización se habla. Sale del usuario, no de un slug en la URL.
    def current_club = current_user.club
  end
end
