class AddFieldsToDispensaciones < ActiveRecord::Migration[7.2]
  def change
    # socio fue renombrado a paciente en 20260429210005 — el schema final usa paciente_id
    add_reference :dispensaciones, :socio, null: false, foreign_key: true unless column_exists?(:dispensaciones, :socio_id)
    add_reference :dispensaciones, :user, null: false, foreign_key: true unless column_exists?(:dispensaciones, :user_id)
    add_reference :dispensaciones, :indicacion_medica, foreign_key: true unless column_exists?(:dispensaciones, :indicacion_medica_id)
    add_reference :dispensaciones, :lote, foreign_key: true unless column_exists?(:dispensaciones, :lote_id)

    add_column :dispensaciones, :cantidad_gramos, :decimal, precision: 8, scale: 2, null: false unless column_exists?(:dispensaciones, :cantidad_gramos)
    add_column :dispensaciones, :tipo_producto, :string, null: false, default: 'flores' unless column_exists?(:dispensaciones, :tipo_producto)
    add_column :dispensaciones, :observaciones, :text unless column_exists?(:dispensaciones, :observaciones)
    add_column :dispensaciones, :fecha_dispensacion, :date, null: false unless column_exists?(:dispensaciones, :fecha_dispensacion)

    add_index :dispensaciones, :fecha_dispensacion unless index_exists?(:dispensaciones, :fecha_dispensacion)
    add_index :dispensaciones, [:socio_id, :fecha_dispensacion] unless index_exists?(:dispensaciones, [:socio_id, :fecha_dispensacion])
  end
end
