# backend/db/migrate/20260320000003_create_movimientos_contables.rb
class CreateMovimientosContables < ActiveRecord::Migration[7.2]
  def change
    create_table :movimientos_contables do |t|
      # Ownership
      t.references :club,  null: false, foreign_key: true
      t.references :sede,  foreign_key: true                  # opcional
      t.references :lote,  foreign_key: true                  # opcional — costo de producción
      t.bigint     :dispensacion_id                           # opcional — recupero por dispensación
      t.bigint     :created_by_id, null: false

      # Clasificación contable
      t.string  :tipo,      null: false  # egreso | ingreso | recupero_costo | ajuste
      t.string  :categoria, null: false  # insumo | electricidad | agua | alquiler | sueldo |
      # mantenimiento | honorario | seguro | admin |
      # aporte_socio | dispensacion | subvencion | otro

      # Datos del movimiento
      t.string  :descripcion, null: false
      t.decimal :monto_ars, precision: 12, scale: 2, null: false
      t.date    :fecha,     null: false

      # Comprobante
      t.string  :comprobante_numero
      t.string  :comprobante_tipo   # factura_a | factura_b | recibo | ticket | sin_comprobante
      t.string  :proveedor

      # Pago
      t.boolean :pagado,     default: false, null: false
      t.string  :medio_pago  # efectivo | transferencia | mercado_pago | cheque

      t.text    :notas

      t.timestamps
    end

    add_index :movimientos_contables, :fecha
    add_index :movimientos_contables, [:club_id, :fecha]
    add_index :movimientos_contables, [:club_id, :tipo]
    add_index :movimientos_contables, [:sede_id, :fecha]
    add_index :movimientos_contables, :dispensacion_id
    add_foreign_key :movimientos_contables, :users,        column: :created_by_id
    add_foreign_key :movimientos_contables, :dispensaciones, column: :dispensacion_id
  end
end