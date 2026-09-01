# La ENTREGA de la recaudación del repartidor, con las dos personas adentro.
#
# Hasta ahora era unilateral: el que recibía apretaba un botón y el sistema daba por rendido todo
# lo que el repartidor había cobrado. Dos agujeros: nadie CONTABA la plata (si traía menos, el
# sistema no se enteraba) y el repartidor no tenía forma de dejar constancia de que la entregó.
#
# LA PLATA NUNCA QUEDA EN EL AIRE. Es efectivo: el que cuenta es el que la tiene, y ese número es
# el que entra a la caja. No hay estado "en disputa" —eso dejaría plata que no está en ningún
# lado—. Lo que sí queda es la CONFORMIDAD del repartidor cuando el receptor ajustó el monto: es
# constancia de si estuvo de acuerdo, y no traba nada.
class CreateRendicionesCaja < ActiveRecord::Migration[7.2]
  def change
    create_table :rendiciones_caja do |t|
      t.references :club,     null: false, foreign_key: true
      t.references :delivery, null: false, foreign_key: { to_table: :users }
      t.references :receptor, foreign_key: { to_table: :users }
      t.references :caja_turno, foreign_key: true

      t.string   :estado, null: false, default: 'pendiente' # pendiente | recibida | anulada
      # Lo que el sistema dice que cobró: la suma de sus cobros en tránsito. NO lo escribe él.
      t.decimal  :monto_declarado_ars, precision: 12, scale: 2, null: false, default: 0
      # Lo que contó el que recibe. Es el que entra a la caja: es quien tiene la plata en la mano.
      t.decimal  :monto_recibido_ars,  precision: 12, scale: 2
      t.string   :motivo_ajuste
      # nil = no hizo falta (coincidió) · false = se ajustó y el repartidor no lo conformó todavía
      # · true = lo conformó. NO es un candado: la plata ya entró.
      t.boolean  :conforme
      t.integer  :cobros_count, null: false, default: 0

      t.datetime :rendida_at
      t.datetime :recibida_at
      t.datetime :conformada_at
      t.timestamps
    end
    add_index :rendiciones_caja, [:club_id, :estado]
    # Una rendición pendiente por repartidor: dos abiertas partirían la misma plata en dos.
    add_index :rendiciones_caja, :delivery_id,
              unique: true, where: "estado = 'pendiente'",
              name: 'index_rendiciones_caja_pendiente_por_delivery'

    # Qué cobros entraron en cada rendición. `rendido_at` los fecha, pero para reconstruir una
    # entrega hay que poder agruparlos por el hecho, no por una ventana de tiempo.
    add_reference :cobros, :rendicion_caja, null: true, index: true,
                  foreign_key: { to_table: :rendiciones_caja }
  end
end
