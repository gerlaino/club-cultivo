class AddConSeguimientoMedicoToPacientes < ActiveRecord::Migration[7.2]
  def change
    add_column :pacientes, :con_seguimiento_medico, :boolean, default: true, null: false
  end
end
