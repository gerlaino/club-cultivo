class AddHistorialEnvioToDispensaciones < ActiveRecord::Migration[7.2]
  # Bitácora de eventos de entrega (creado / despachado / fallo / reprogramado /
  # cancelado / entregado), cada uno con fecha, usuario y motivo. Trazabilidad
  # completa del recorrido del paquete sin perder información.
  def change
    add_column :dispensaciones, :historial_envio, :jsonb, default: [], null: false
  end
end
