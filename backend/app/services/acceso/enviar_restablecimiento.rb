# Manda el link para elegir una contraseña nueva. UNA sola forma de hacerlo, porque la piden
# tres puertas —«olvidé mi contraseña» en el login, el reset del panel de plataforma y el de la
# ficha de la organización— y hasta sep-2026 dos de ellas usaban el mail de Devise, cuyo link
# apuntaba a una vista HTML que esta app (API) no sirve, y sólo si la ORGANIZACIÓN tenía SMTP.
#
# Sale por la casilla de la PLATAFORMA y a `User#email_real`: sin casilla real no se manda
# nada, y devuelve false para que quien lo pidió lo diga en vez de prometer un mail.
module Acceso
  class EnviarRestablecimiento
    def self.call(user) = new(user).call

    def initialize(user)
      @user = user
    end

    def call
      return false if @user.email_real.blank?

      raw, enc = Devise.token_generator.generate(User, :reset_password_token)
      @user.update_columns(reset_password_token: enc, reset_password_sent_at: Time.current)
      AccesoMailer.restablecer_contrasena(user: @user, token: raw).deliver_later
      true
    rescue StandardError => e
      # Un fallo de SMTP no puede tumbar un reset ni un alta: la clave ya cambió y quien lo
      # hizo la tiene en pantalla para dictarla.
      Rails.logger.warn("[acceso] no se pudo mandar el restablecimiento a #{@user.email}: #{e.class} #{e.message}")
      false
    end
  end
end
