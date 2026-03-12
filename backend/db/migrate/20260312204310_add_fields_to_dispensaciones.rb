class AddFieldsToDispensaciones < ActiveRecord::Migration[7.2]
  def change
    add_reference :dispensaciones, :socio, null: false, foreign_key: true
    add_reference :dispensaciones, :user, null: false, foreign_key: true
    add_reference :dispensaciones, :indicacion_medica, foreign_key: true
    add_reference :dispensaciones, :lote, foreign_key: true

    add_column :dispensaciones, :cantidad_gramos, :decimal, precision: 8, scale: 2, null: false
    add_column :dispensaciones, :tipo_producto, :string, null: false, default: 'flores'
    add_column :dispensaciones, :observaciones, :text
    add_column :dispensaciones, :fecha_dispensacion, :date, null: false

    add_index :dispensaciones, :fecha_dispensacion
    add_index :dispensaciones, [:socio_id, :fecha_dispensacion]
  end
end
