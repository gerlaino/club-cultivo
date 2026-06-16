class CreateReservas < ActiveRecord::Migration[7.2]
  def change
    create_table :reservas do |t|
      t.references :club,         null: false, foreign_key: true
      t.references :paciente,     null: false, foreign_key: true
      t.references :stock,        null: false, foreign_key: true
      t.references :user,         null: false, foreign_key: true   # quién reservó
      t.references :dispensacion, null: true,  foreign_key: { to_table: :dispensaciones }   # se completa al entregar

      t.decimal :cantidad,             precision: 10, scale: 3, null: false
      t.string  :estado,               null: false, default: 'pendiente'
      t.date    :fecha_entrega_estimada, null: false

      t.decimal :sena_ars,             precision: 10, scale: 2, default: 0, null: false
      t.decimal :aporte_estimado_ars,  precision: 10, scale: 2
      t.string  :medio_pago

      # Reserva con entrega a domicilio (espeja los campos de Dispensacion)
      t.boolean :con_envio,            null: false, default: false
      t.string  :direccion_envio
      t.string  :contacto_nombre
      t.string  :contacto_telefono

      t.text     :notas
      t.datetime :entregada_at
      t.datetime :cancelada_at
      t.datetime :vencida_at

      t.timestamps
    end

    add_index :reservas, [:club_id, :estado]
    add_index :reservas, [:stock_id, :estado]
    add_index :reservas, :fecha_entrega_estimada
  end
end
