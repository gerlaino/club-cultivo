# Qué partes del portal atiende la organización (Germán, 28-oct-2026: «Armá tu portal»). Reservar
# y Mensajes piden que alguien conteste; quien no los va a atender los apaga y no aparecen. Lo
# demás (credencial, REPROCANN, dispensas) es del paciente y no se apaga.
class PartesDelPortalPorOrganizacion < ActiveRecord::Migration[7.2]
  def change
    add_column :clubs, :portal_reservar_activo, :boolean, default: true, null: false
    add_column :clubs, :portal_mensajes_activo, :boolean, default: true, null: false
  end
end
