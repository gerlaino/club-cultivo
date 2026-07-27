# Cierre honesto de lo apartado para un evento. Lo apartado (Stock) sale del inventario por dos
# vías, y hay que poder distinguirlas:
#   • DISPENSADO: el dispensador entrega a un socio durante el evento, desde lo reservado.
#     `dispensacion_items.evento_bar_id` deja el rastro de que esa línea salió del apartado del
#     evento (trazabilidad: qué evento consumió qué gramos, con su paciente).
#   • CONSUMO INTERNO: se consumió en el evento sin dispensar a nadie identificable
#     (degustación, muestra). `cantidad_consumo_interno` lo separa de lo dispensado; descuenta al
#     cerrar con un StockMovimiento tipo `consumo_evento` y suma al COGS del evento.
class AddConsumoEventoAProvisionesYDispensas < ActiveRecord::Migration[7.2]
  def change
    add_column :evento_bar_provisiones, :cantidad_consumo_interno, :decimal,
               precision: 12, scale: 2, default: 0, null: false

    # to_table explícito: el inflector inglés deduce "evento_bares" y la tabla real es "eventos_bar".
    add_reference :dispensacion_items, :evento_bar, null: true,
                  foreign_key: { to_table: :eventos_bar }
  end
end
