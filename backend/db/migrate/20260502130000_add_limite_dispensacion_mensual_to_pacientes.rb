class AddLimiteDispensacionMensualToPacientes < ActiveRecord::Migration[7.2]
  def change
    add_column :pacientes, :limite_dispensacion_mensual_g, :decimal, precision: 8, scale: 2
  end
end
