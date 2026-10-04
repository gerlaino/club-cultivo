class JwtDenylist < ApplicationRecord
  include Devise::JWT::RevocationStrategies::Denylist

  self.table_name = 'jwt_denylists'

  # Un token cerrado se puede olvidar recién cuando YA VENCIÓ solo. Antes se borraba a las 12 h de
  # cerrado, que era la vida del token; con sesiones de 7 días, borrarlo antes lo revivía.
  scope :expired, -> { where('exp < ?', Time.current) }

  # Además de los tokens cerrados a mano (logout), vence todo token abierto con otra contraseña:
  # cambiarla corta las sesiones en los demás dispositivos. Los tokens sin huella (de antes de
  # que existiera) se aceptan hasta que expiren solos, para no desloguear a todos al deployar.
  #
  # NO llamar a `super`: el `include` de devise-jwt define `jwt_revoked?` en la PROPIA clase (en un
  # `included do`), así que redefinirlo acá lo reemplaza y no hay método padre. Del 25-sep al 4-oct
  # fue `return true if super`, que reventaba en TODO pedido autenticado sólo con el token (la app
  # nativa, o la web cuando el navegador ya no tenía la cookie de sesión de Rails, como el iPhone al
  # cerrar la PWA): la pantalla perdía el usuario y mandaba al login.
  def self.jwt_revoked?(payload, user)
    return true if exists?(jti: payload['jti'])
    payload['pwd'].present? && payload['pwd'] != user.huella_contrasena
  end
end
