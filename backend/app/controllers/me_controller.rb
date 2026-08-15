class MeController < ApplicationController
  before_action :authenticate_user!
  # Quién soy: lo consulta cualquier rol, incluido el super admin al arrancar la app.
  skip_before_action :block_super_admin_sin_contexto!

  def show
    u = current_user
    data = u.as_json(
      only: %i[id email role club_id first_name last_name dni birthdate phone created_at updated_at]
    )
    # avatar_url no es columna: es la URL del adjunto ActiveStorage. Con `only:` se
    # ignoraba, por eso el ícono nunca recibía el avatar tras /me ni refreshUser.
    data['avatar_url'] = u.avatar.attached? ? url_for(u.avatar) : nil

    # Modo observador: el super admin está viendo un club ajeno en solo lectura. El frontend lo
    # necesita para montar el shell del club en vez del de plataforma y para mostrar el cartel
    # permanente — sin eso, la sesión se ve idéntica a estar adentro de verdad.
    #
    # `club_id` ya viene enmascarado con el club observado (ver User#club_id): es a propósito,
    # es el club contra el que trabaja el request.
    if u.modo_observador?
      club = u.observando_club
      data['observando'] = {
        club_id:            club&.id,
        club_nombre:        club&.name,
        expires_at:         u.observer_expires_at,
        solo_lectura:       true,
        sin_acceso_clinico: true,
      }
    end

    if u.dispensador?
      data['dispensario_sede_id'] =
        u.sedes_asignadas.activas.first&.id ||
        u.club&.sedes&.activas&.where(tipo: %w[social mixta])&.order(:id)&.first&.id
    end
    # Reglas de dominio que el frontend necesita para no dejar elegir combinaciones que el
    # backend después rechaza. Viajan acá —y no en una copia hardcodeada en el front— porque
    # tenerlas dos veces es tenerlas mal: hasta que se sincronizaron a mano, el modal ofrecía
    # "Enraizado" en una sala de floración y el alta moría con un 422.
    #
    # Va en /me a propósito: el router espera este request antes de montar cualquier pantalla,
    # así que la regla siempre está antes de que se pueda abrir un formulario.
    data['reglas_cultivo'] = { 'kinds_sala_por_estado' => Lote::KINDS_SALA_POR_ESTADO }

    render json: data
  end
end

