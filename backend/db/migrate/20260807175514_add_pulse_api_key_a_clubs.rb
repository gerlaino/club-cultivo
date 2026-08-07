class AddPulseApiKeyAClubs < ActiveRecord::Migration[7.2]
  # Credencial de la nube de Pulse Grow, por club. Va acá y no en cada dispositivo porque la
  # cuenta de Pulse es del club: con una sola key se leen todos sus sensores.
  #
  # Cifrada con el mismo criterio que el token de Twilio: es la llave de la cuenta de un
  # cliente y no tiene por qué quedar legible en la base ni en un backup.
  def change
    add_column :clubs, :pulse_api_key_enc, :text
  end
end
