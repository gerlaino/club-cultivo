# Quien se registró solo, para uso personal, desde /bienvenida (ver la migración que la crea).
#
# La cuenta ya existe y anda; esto guarda dos cosas que el alta por super admin no necesita:
#   · el mail: se confirma DESPUÉS de entrar. Hay `GRACIA` días desde que el mail SALIÓ; sin
#     confirmar, la cuenta se pausa (suspensión `mail_sin_confirmar`) hasta que toque el link. Si el
#     mail nunca salió (el correo de la plataforma falló), no corre ningún reloj: no se le puede
#     pedir a nadie que confirme algo que no le llegó.
#   · la constancia de que aceptó los términos: versión, cuándo, IP y navegador.
#
# El token del link no se guarda: se guarda su digest (igual que Devise con la contraseña). Quien
# lea la tabla no puede confirmar cuentas ajenas.
class RegistroPersonal < ApplicationRecord
  self.table_name = 'registros_personales'

  GRACIA = 7.days

  belongs_to :club
  belongs_to :user

  validates :email, :token_digest, :terminos_version, :terminos_aceptados_at, presence: true

  scope :sin_confirmar, -> { where(confirmado_at: nil) }

  def self.digest(token) = OpenSSL::Digest::SHA256.hexdigest(token.to_s)

  # Un token nuevo cada vez que se manda el mail: el link viejo deja de servir.
  def nuevo_token!
    token = SecureRandom.urlsafe_base64(32)
    update!(token_digest: self.class.digest(token))
    token
  end

  def self.por_token(token)
    return nil if token.blank?

    find_by(token_digest: digest(token))
  end

  def confirmado? = confirmado_at.present?

  # Hasta cuándo puede seguir sin confirmar. Nil: no hay reloj (ya confirmó, o el mail no salió).
  def pausa_el
    return nil if confirmado? || mail_enviado_at.nil?

    (mail_enviado_at + GRACIA).to_date
  end

  # Confirmar también DESPAUSA: si la cuenta se pausó por no confirmar, el link es lo que la
  # devuelve. Una pausa por otro motivo (prueba terminada) no se toca.
  def confirmar!
    transaction do
      update!(confirmado_at: Time.current) unless confirmado?
      club.reactivar! if club.suspendido? && club.suspension_motivo == 'mail_sin_confirmar'
    end
  end
end
