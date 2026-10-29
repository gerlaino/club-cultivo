# Segundo paso al entrar (29-oct-2026, seguridad tanda 2, AUTH-2FA; Germán: «sí»). El super admin
# entraba sólo con mail y clave y abre todas las organizaciones: ahora además pide el código de seis
# números de una app (Google Authenticator, 1Password…). Ver `Seguridad::Totp`.
#
# - `otp_secret`: el secreto que comparten la app y el servidor. Va cifrado (`encrypts` en User).
# - `otp_activado_at`: desde cuándo se pide. Con secreto y sin fecha = lo empezó a activar y no
#   terminó (todavía no se pide).
# - `otp_ultimo_paso`: el último código usado, para que el mismo no sirva dos veces.
class SegundoPasoParaEntrar < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :otp_secret,      :string
    add_column :users, :otp_activado_at, :datetime
    add_column :users, :otp_ultimo_paso, :bigint
  end
end
