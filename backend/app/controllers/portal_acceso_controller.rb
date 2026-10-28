# La puerta del portal del paciente, sin sesión (27-oct-2026):
#
#   POST /api/portal_acceso/sesion               DNI + clave (+ organización si es paciente en varias)
#   GET  /api/portal_acceso/links/:token          qué link es (para la pantalla de activar)
#   POST /api/portal_acceso/links/:token/activar  DNI + clave nueva → entra
#   POST /api/portal_acceso/recuperar             DNI → link por mail
#   GET  /api/portal_acceso/organizaciones/:slug  la puerta de UNA organización (nombre y logo)
#
# Sesión y recuperar aceptan `organizacion` (el slug de la puerta `/paciente/<slug>`): por ahí todo
# queda en esa organización. Sin él (la puerta general `/paciente`) es una por cada una en la que
# es paciente, y si la clave sirve en varias elige después de validar.
#
# Las cuatro las limita rack-attack por IP. Entrar y activar devuelven el token de sesión igual
# que el login del equipo (`jwt.dispatch_requests`, la cookie la pone `JwtCookieMiddleware`).
class PortalAccesoController < ApplicationController
  skip_before_action :authenticate_user!, raise: false
  skip_before_action :set_tenant_from_current_user, raise: false
  skip_before_action :check_club_activo!, raise: false
  skip_before_action :check_rol_habilitado!, raise: false
  skip_before_action :block_super_admin_sin_contexto!, raise: false

  CLAVE_MINIMA = 8
  ERROR_CREDENCIALES = 'El DNI o la clave no son correctos.'.freeze

  # POST /api/portal_acceso/sesion
  #
  # Si la clave sirve en una sola organización, entra. Si sirve en varias, contesta cuáles (sólo
  # ahí, después de validar) y la pantalla vuelve a mandar lo mismo con `organizacion_id`.
  def sesion
    cuentas = PortalAcceso::Cuentas.con_clave(params[:dni], params[:password], organizacion: params[:organizacion])
    return render json: { error: ERROR_CREDENCIALES }, status: :unauthorized if cuentas.empty?

    if cuentas.size > 1
      elegida = cuentas.find { |u| u.club_id.to_s == params[:organizacion_id].to_s }
      return render json: { elegir: cuentas.map { |u| organizacion_json(u.club) } } unless elegida

      cuentas = [elegida]
    end

    entrar!(cuentas.first)
  end

  # El link llega sin sesión y sin organización: la organización sale del link. Todo lo que lee la
  # ficha del paciente corre con ese tenant (sin él, `require_tenant` corta con NoTenantSet).
  around_action :con_la_organizacion_del_link, only: %i[link activar]

  # GET /api/portal_acceso/links/:token
  def link
    acceso = @acceso
    return render json: { error: 'Este link no existe. Revisá que esté completo.' }, status: :not_found unless acceso

    if (motivo = acceso.motivo_invalido)
      return render json: { error: motivo, organizacion: organizacion_json(acceso.club) }, status: :gone
    end

    render json: {
      motivo:       acceso.motivo,
      nombre:       acceso.paciente.nombre.to_s.split.first,
      organizacion: organizacion_json(acceso.club),
      expira_at:    acceso.expira_at,
    }
  end

  # POST /api/portal_acceso/links/:token/activar
  def activar
    acceso = @acceso
    return render json: { error: 'Este link no existe. Revisá que esté completo.' }, status: :not_found unless acceso
    return render json: { error: acceso.motivo_invalido }, status: :gone unless acceso.vigente?

    ficha = acceso.paciente
    if ficha.dni_normalizado != params[:dni].to_s.gsub(/\D/, '')
      acceso.registrar_intento_fallido!
      return render json: { error: acceso.vigente? ? 'Ese DNI no es el de este link.' : acceso.motivo_invalido },
                    status: :unprocessable_entity
    end

    unless PortalAcceso::Cuentas.fichas(ficha.dni_normalizado).include?(ficha)
      return render json: { error: 'Tu organización tiene el portal cerrado por ahora. Hablá con ellos.' }, status: :forbidden
    end

    password = params[:password].to_s
    if password.length < CLAVE_MINIMA
      return render json: { error: "La clave tiene que tener al menos #{CLAVE_MINIMA} caracteres." }, status: :unprocessable_entity
    end
    if password != params[:password_confirmation].to_s
      return render json: { error: 'Las dos claves no son iguales.' }, status: :unprocessable_entity
    end

    user = Pacientes::Acceso.crear!(ficha).user
    ActiveRecord::Base.transaction do
      user.update!(password: password, password_confirmation: password)
      acceso.usar!
    end
    entrar!(user)
  end

  # POST /api/portal_acceso/recuperar
  #
  # «Me olvidé la clave» y «Es mi primera vez» son la misma puerta (Germán, 28-oct-2026: que el
  # paciente entre solo con el QR del mostrador, sin esperar que alguien lo invite): el que ya
  # eligió su clave recibe un link para cambiarla; el que nunca entró, la invitación.
  #
  # Siempre contesta lo mismo: decir «ese DNI no está» le diría a cualquiera quién es paciente.
  # Un link sin usar que se mandó hace menos de ESPERA_ENTRE_LINKS no se reemplaza: si no, cualquiera que
  # tipee un DNI ajeno anula el link que la organización le acaba de mandar, y le llena el correo.
  ESPERA_ENTRE_LINKS = 10.minutes

  def recuperar
    fichas = PortalAcceso::Cuentas.fichas(params[:dni], organizacion: params[:organizacion]).select do |ficha|
      ficha.email.present? &&
        ActsAsTenant.with_tenant(ficha.club) do
          !ficha.accesos_portal.where(usado_at: nil, anulado_at: nil).where('created_at > ?', ESPERA_ENTRE_LINKS.ago).exists?
        end
    end

    # Paciente en más de una organización con el mismo mail: UN mail con un botón por cada una, y
    # elige ahí (Germán, 28-oct-2026: «habría que elegir de qué organización hablás»). La elección
    # pasa dentro de SU casilla: mostrar la lista en pantalla le decía a cualquiera que tipeara un
    # DNI ajeno dónde es paciente. Sale por la casilla de la plataforma: por la de una organización,
    # esa organización se enteraría (su carpeta de enviados) de las otras.
    fichas.group_by { |f| f.email.to_s.strip.downcase }.each_value do |del_mail|
      if del_mail.size == 1
        ficha = del_mail.first
        ActsAsTenant.with_tenant(ficha.club) { PortalAcceso::Invitar.call(ficha, motivo: motivo_de(ficha)) }
      else
        PortalAcceso::InvitarVarias.call(del_mail) { |ficha| motivo_de(ficha) }
      end
    end

    render json: {
      mensaje: 'Si tu DNI está en una organización con portal y tenés un mail cargado, te mandamos un link ' \
               'a ese mail para elegir tu clave. Si sos paciente en más de una, en el mail elegís a cuál. ' \
               'Si no te llega en unos minutos, pedile el link a tu organización en el mostrador.',
    }
  end

  # GET /api/portal_acceso/organizaciones/:slug
  #
  # La cara de la puerta de una organización: su nombre y su logo, para que el paciente sepa a cuál
  # está entrando ANTES de poner nada. Es lo mismo que dice su cartel del mostrador; no dice nada
  # de ningún paciente. Con el portal cerrado (o un slug que no existe) contesta lo mismo.
  def organizacion
    club = PortalAcceso::Cuentas.puerta(params[:slug])
    return render json: { error: 'Esta organización no tiene el portal del paciente abierto.' }, status: :not_found unless club

    render json: organizacion_json(club)
  end

  private

  def motivo_de(ficha) = ficha.portal_activado? ? 'recuperacion' : 'invitacion'

  def con_la_organizacion_del_link(&accion)
    @acceso = AccesoPortal.por_token(params[:token])
    return accion.call unless @acceso

    ActsAsTenant.with_tenant(@acceso.club, &accion)
  end

  def entrar!(user)
    sign_in(:user, user)
    user.update_column(:visto_at, Time.current)
    render json: { id: user.id, role: user.role, club_id: user.club_id, first_name: user.first_name }
  end

  def organizacion_json(club)
    {
      id:            club.id,
      slug:          club.slug,
      nombre:        club.name,
      logo_url:      club.logo.attached? ? url_for(club.logo) : nil,
      theme_primary: club.theme_primary,
    }
  end
end
