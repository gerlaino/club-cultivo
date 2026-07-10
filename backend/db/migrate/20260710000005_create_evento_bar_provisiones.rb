class CreateEventoBarProvisiones < ActiveRecord::Migration[7.2]
  # Provisión de un evento: qué productos y cuánto se necesitan. Con reserva:
  #   prevista  = lo que se estima necesitar
  #   reservada = lo que efectivamente se apartó del depósito (sale del stock)
  #   consumida = lo que se usó/vendió durante el evento (de lo reservado)
  # Al cerrar el evento, el sobrante (reservada - consumida) vuelve al depósito.
  def change
    create_table :evento_bar_provisiones do |t|
      t.references :club,         null: false, foreign_key: true
      t.references :evento_bar,   null: false, foreign_key: { to_table: :eventos_bar }
      t.references :bar_producto, null: false, foreign_key: true

      t.decimal :cantidad_prevista,  precision: 12, scale: 2, null: false, default: 0
      t.decimal :cantidad_reservada, precision: 12, scale: 2, null: false, default: 0
      t.decimal :cantidad_consumida, precision: 12, scale: 2, null: false, default: 0

      t.timestamps
    end

    add_index :evento_bar_provisiones, [:evento_bar_id, :bar_producto_id], unique: true,
              name: 'index_provisiones_evento_producto'
  end
end
