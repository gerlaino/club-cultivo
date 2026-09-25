class JwtDenylist < ApplicationRecord
  include Devise::JWT::RevocationStrategies::Denylist

  self.table_name = 'jwt_denylists'

  scope :expired, -> { where('created_at < ?', 12.hours.ago) }

  # Además de los tokens cerrados a mano (logout), vence todo token abierto con otra contraseña:
  # cambiarla corta las sesiones en los demás dispositivos. Los tokens sin huella (de antes de
  # que existiera) se aceptan hasta que expiren solos, para no desloguear a todos al deployar.
  def self.jwt_revoked?(payload, user)
    return true if super
    payload['pwd'].present? && payload['pwd'] != user.huella_contrasena
  end
end
