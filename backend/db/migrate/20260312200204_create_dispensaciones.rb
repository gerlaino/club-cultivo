class CreateDispensaciones < ActiveRecord::Migration[7.2]
  def change
    create_table :dispensaciones do |t|
      t.references :socio, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :indicacion_medica, foreign_key: true
      t.references :lote, foreign_key: true

      t.decimal :cantidad_gramos, precision: 8, scale: 2, null: false
      t.string :tipo_producto, null: false, default: 'flores'
      t.text :observaciones
      t.date :fecha_dispensacion, null: false

      t.timestamps
    end

    add_index :dispensaciones, :fecha_dispensacion
    add_index :dispensaciones, [:socio_id, :fecha_dispensacion]
  end
end
