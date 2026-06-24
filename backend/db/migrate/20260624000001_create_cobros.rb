class CreateCobros < ActiveRecord::Migration[7.2]
  def change
    create_table :cobros do |t|
      t.references :dispensacion, null: false, foreign_key: { to_table: :dispensaciones }
      t.references :club,         null: false, foreign_key: true
      t.references :created_by,   null: false, foreign_key: { to_table: :users }

      # efectivo / transferencia / cuenta_corriente
      t.string  :medio,     null: false
      t.decimal :monto_ars, null: false, precision: 12, scale: 2
      # efectivo/transferencia = true (entró plata); cuenta_corriente = false (deuda)
      t.boolean :pagado,    null: false, default: true
      # Dónde se cargó el cobro: creacion (dispensar) / entrega (delivery) / contabilidad
      t.string  :contexto,  null: false, default: 'creacion'
      t.text    :notas

      t.timestamps
    end

    add_index :cobros, [:club_id, :created_at]
    add_index :cobros, [:dispensacion_id, :medio]

    # Marca que el cobro lo hace el delivery al entregar (contra-entrega): al crear no
    # se asienta nada financiero; los cobros se cargan en la entrega.
    add_column :dispensaciones, :cobrar_en_entrega, :boolean, null: false, default: false
  end
end
