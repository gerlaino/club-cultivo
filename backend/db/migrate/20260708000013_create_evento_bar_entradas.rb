class CreateEventoBarEntradas < ActiveRecord::Migration[7.2]
  # Tipos de entrada de un evento (Early bird, General, VIP…) y las entradas individuales
  # vendidas. El ingreso se agrega por tipo en el libro (vendidas * precio). Cada entrada lleva
  # un código único para el QR (Capa 4). Todo recuperable.
  def change
    create_table :evento_bar_tipos_entrada do |t|
      t.references :club,                null: false, foreign_key: true
      t.references :evento_bar,          null: false, foreign_key: { to_table: :eventos_bar }
      t.references :movimiento_contable, null: true,  foreign_key: { to_table: :movimientos_contables }
      t.references :deleted_by,          null: true,  foreign_key: { to_table: :users }
      t.string  :nombre, null: false
      t.decimal :precio_ars, precision: 12, scale: 2, null: false, default: 0
      t.integer :cupo
      t.integer :orden,  null: false, default: 0
      t.boolean :activo, null: false, default: true
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :evento_bar_tipos_entrada, :deleted_at

    create_table :evento_bar_entradas do |t|
      t.references :club,       null: false, foreign_key: true
      t.references :evento_bar, null: false, foreign_key: { to_table: :eventos_bar }
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :deleted_by, null: true,  foreign_key: { to_table: :users }
      t.bigint  :evento_bar_tipo_entrada_id, null: false
      t.string  :codigo, null: false          # token para el QR (Capa 4)
      t.string  :comprador
      t.decimal :precio_ars, precision: 12, scale: 2, null: false
      t.string  :estado, null: false, default: 'valida' # valida/usada/anulada
      t.datetime :check_in_at
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :evento_bar_entradas, :codigo, unique: true
    add_index :evento_bar_entradas, :deleted_at
    add_index :evento_bar_entradas, :evento_bar_tipo_entrada_id, name: 'idx_entradas_on_tipo'
    add_foreign_key :evento_bar_entradas, :evento_bar_tipos_entrada, column: :evento_bar_tipo_entrada_id
  end
end
