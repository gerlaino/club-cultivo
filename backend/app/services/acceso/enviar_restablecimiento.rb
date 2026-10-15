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

    # Varias cuentas a la vez (el «Olvidé mi contraseña» con un mail que comparten). UN mail por
    # casilla, con un botón por cuenta: antes salía un mail por cuenta y a la misma persona le
    # llegaban tres iguales (15-oct-2026). Devuelve cuántas cuentas quedaron con link.
    def self.a_varias(users)
      users.select { |u| u.email_real.present? }.group_by { |u| u.email_real.downcase }.sum do |_casilla, cuentas|
        next(call(cuentas.first) ? 1 : 0) if cuentas.size == 1

        con_token = cuentas.map { |u| [u, new(u).generar_token!] }
        AccesoMailer.restablecer_varias(cuentas: con_token).deliver_later
        cuentas.size
      rescue StandardError => e
        Rails.logger.warn("[acceso] no se pudo mandar el restablecimiento a varias cuentas: #{e.class} #{e.message}")
        0
      end
    end

    def initialize(user)
      @user = user
    end

    def call
      return false if @user.email_real.blank?

      AccesoMailer.restablecer_contrasena(user: @user, token: generar_token!).deliver_later
      true
    rescue StandardError => e
      # Un fallo de SMTP no puede tumbar un reset ni un alta: la clave ya cambió y quien lo
      # hizo la tiene en pantalla para dictarla.
      Rails.logger.warn("[acceso] no se pudo mandar el restablecimiento a #{@user.email}: #{e.class} #{e.message}")
      false
    end

    # El token crudo va en el link; en la base queda el cifrado, como lo guarda Devise.
    def generar_token!
      raw, enc = Devise.token_generator.generate(User, :reset_password_token)
      @user.update_columns(reset_password_token: enc, reset_password_sent_at: Time.current)
      raw
    end
  end
end
