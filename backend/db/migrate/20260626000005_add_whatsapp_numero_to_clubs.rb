class AddWhatsappNumeroToClubs < ActiveRecord::Migration[7.2]
  # Número de WhatsApp que el club quiere usar para enviar (lo carga el admin al "solicitar
  # activación"). El super_admin lo registra en Twilio y carga las credenciales. El estado
  # (sin_configurar/pendiente/conectado) se DERIVA, no se persiste.
  def change
    add_column :clubs, :whatsapp_numero, :string
  end
end
