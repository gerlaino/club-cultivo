# Qué avisos quiere recibir cada persona en el teléfono (push), por tipo, más «no molestar».
# La campanita no se configura: es el registro. Ver `Notificaciones::Catalogo`.
class AddNotificacionesConfigAUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :notificaciones_config, :jsonb, null: false, default: {}
  end
end
