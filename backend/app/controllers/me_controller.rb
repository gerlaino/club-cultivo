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
      # SÓLO SEDES QUE ATIENDEN. El mostrador vive en las `social`/`mixta`: una organización con
      # cultivo tiene además sedes de producción, y si el dispensador tenía una asignada primero
      # —la lista no está ordenada por nada en particular— se le devolvía como su mostrador. La
      # tarjeta de caja le contestaba "no se pudo cargar el mostrador" sin decir por qué, y no
      # había forma de arreglarlo desde la pantalla.
      sede_mostrador = u.sede_de_mostrador
      data['dispensario_sede_id'] = sede_mostrador&.id
      # Con el nombre: la tarjeta de caja lo muestra y la PWA no tiene de dónde sacarlo sin
      # pedir el listado de sedes entero en la pantalla que más se usa.
      data['dispensario_sede'] = sede_mostrador && { 'id' => sede_mostrador.id, 'nombre' => sede_mostrador.nombre }
    end
    # Reglas de dominio que el frontend necesita para no dejar elegir combinaciones que el
    # backend después rechaza. Viajan acá —y no en una copia hardcodeada en el front— porque
    # tenerlas dos veces es tenerlas mal: hasta que se sincronizaron a mano, el modal ofrecía
    # "Enraizado" en una sala de floración y el alta moría con un 422.
    #
    # Va en /me a propósito: el router espera este request antes de montar cualquier pantalla,
    # así que la regla siempre está antes de que se pueda abrir un formulario.
    data['reglas_cultivo'] = { 'kinds_sala_por_estado' => Lote::KINDS_SALA_POR_ESTADO,
                               # La misma tabla para una genética automática (en floración
                               # sigue valiendo la sala de vege). La pantalla elige cuál usar
                               # según la genética; no escribe la excepción.
                               'kinds_sala_por_estado_automatica' => Lote::KINDS_SALA_POR_ESTADO_AUTOMATICA,
                               # A qué sedes se asigna cada rol: la pantalla ofrece sólo eso.
                               'sedes_por_rol'         => Sede::TIPOS_POR_ROL,
                               # Dónde puede enraizar un lote: el desplegable ofrece esto.
                               'metodos_enraizado'     => Lote::METODOS_ENRAIZADO,
                               # Suelo vivo: para qué es cada receta y en qué se dosifica, qué se le
                               # hace a una cama, qué agua, y qué tareas de un plan no aplican en cama.
                               'suelo_vivo' => {
                                 'usos_receta'        => Receta::USOS,
                                 'usos_receta_labels' => Receta::USO_LABELS,
                                 'unidades_por_uso'   => Receta::UNIDADES_POR_USO,
                                 'unidad_labels'      => RecetaItem::UNIDAD_LABELS,
                                 'base_unidad'        => Receta::BASE_UNIDAD,
                                 'tipos_registro'     => CamaRegistro::TIPOS,
                                 'tipos_registro_labels' => CamaRegistro::TIPO_LABELS,
                                 'aguas'              => CamaRegistro::AGUAS,
                                 'tareas_no_aplican'  => Tarea::NO_APLICAN_EN_CAMA,
                               } }

    # La clave pública VAPID con la que el navegador se suscribe a las notificaciones push. Viaja
    # acá y NO en el build del frontend: hasta el 19-sep-2026 salía de `VITE_VAPID_PUBLIC_KEY`,
    # que en Render nadie pasaba al `npm run build`, y Vite compilaba `subscribe()` como
    # `return false` — «Activar notificaciones» no hacía nada y nunca hubo una suscripción a la
    # que mandarle un push. El backend es el único que tiene el par (`PushNotificationJob`), así
    # que es el que dice con cuál suscribirse; `nil` = este servidor no manda push y la pantalla
    # no ofrece el botón.
    data['push_vapid_public_key'] = ENV['VAPID_PUBLIC_KEY'].presence

    render json: data
  end
end

