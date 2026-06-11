class AddUnidadToCuentaCorrienteMovimientos < ActiveRecord::Migration[7.2]
  def up
    add_column :cuenta_corriente_movimientos, :unidad, :string, default: 'ars', null: false
    # Corregir movimientos de crédito gramos ya existentes
    execute <<~SQL
      UPDATE cuenta_corriente_movimientos
      SET unidad = 'gramos'
      WHERE tipo = 'debito'
        AND descripcion LIKE '%(crédito gramos)%'
    SQL
  end

  def down
    remove_column :cuenta_corriente_movimientos, :unidad
  end
end
