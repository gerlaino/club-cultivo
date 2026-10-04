# El autoregistro de uso personal (/bienvenida → «Probar gratis»), plan A de Germán (4-oct-2026):
# la persona pone nombre, mail y contraseña y ENTRA en el momento; el mail se confirma después.
#
# Arma lo mismo que el alta de uso personal del super admin (`SuperAdmin::ClubsController#create`
# con plan `personal`): un club personal con sólo Cultivo, su usuario admin que entra con su
# mail, las genéticas globales y la sede «Mi cultivo». Más lo propio del autoregistro: la prueba
# de `DIAS_PRUEBA` días y la constancia de los términos (`RegistroPersonal`).
#
# Devuelve el `RegistroPersonal` o levanta `Error` con un texto para mostrar tal cual.
module Registros
  class CrearPersonal
    class Error < StandardError; end

    DIAS_PRUEBA      = 30
    PASSWORD_MINIMO  = 8

    def initialize(nombre:, email:, password:, acepta_terminos:, ip: nil, user_agent: nil)
      @nombre     = nombre.to_s.strip.squish
      @email      = email.to_s.strip.downcase
      @password   = password.to_s
      @acepta     = ActiveModel::Type::Boolean.new.cast(acepta_terminos)
      @ip         = ip
      @user_agent = user_agent.to_s.first(255)
    end

    def call
      validar!

      registro = nil
      # Es de plataforma: crea una organización, así que no corre con el tenant de nadie (las
      # genéticas globales se buscan sin tenant; lo del club nuevo fija el suyo adentro).
      ActsAsTenant.without_tenant do
        Club.transaction do
          club = Club.create!(
            name: "Cultivo de #{@nombre}".first(80), email: @email, plan: 'personal',
            features: Club::FEATURES_PERSONAL.dup,
            plan_trial: true, plan_activo_hasta: Time.zone.today + DIAS_PRUEBA,
          )
          partes = @nombre.split(' ', 2)
          user = club.crear_usuarios_default!(
            roles: ['admin'], password: @password,
            admin: { first_name: partes[0], last_name: partes[1].presence || '', email_personal: @email },
          ).first
          raise Error, 'No se pudo crear la cuenta. Probá de nuevo.' unless user

          club.crear_geneticas_default!
          Clubs::SembrarPersonal.new(club, por: user).call
          registro = RegistroPersonal.create!(
            club: club, user: user, email: @email,
            token_digest: RegistroPersonal.digest(SecureRandom.urlsafe_base64(32)),
            terminos_version: Legal::TERMINOS_VERSION, terminos_aceptados_at: Time.current,
            ip: @ip, user_agent: @user_agent,
          )
        end
      end
      registro
    end

    private

    def validar!
      raise Error, 'Poné tu nombre.' if @nombre.blank?
      raise Error, 'El nombre es muy largo.' if @nombre.length > 80
      raise Error, 'Ese mail no parece válido.' unless @email.match?(URI::MailTo::EMAIL_REGEXP)
      raise Error, "La contraseña tiene que tener al menos #{PASSWORD_MINIMO} caracteres." if @password.length < PASSWORD_MINIMO
      raise Error, 'Para crear la cuenta tenés que aceptar los términos y la política de privacidad.' unless @acepta
      # Mismo texto exista o no en otra organización: no se le confirma a un extraño qué mails
      # tienen cuenta más de lo imprescindible, pero quien ya la tiene necesita saber qué hacer.
      return unless User.unscoped.exists?(email: @email) || User.unscoped.exists?(email_personal: @email)

      raise Error, 'Ya hay una cuenta con ese mail. Entrá con él, o recuperá la contraseña si no la recordás.'
    end
  end
end
