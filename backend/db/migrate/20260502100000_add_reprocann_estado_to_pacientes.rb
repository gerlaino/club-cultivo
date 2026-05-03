class AddReprocannEstadoToPacientes < ActiveRecord::Migration[7.2]
  def change
    add_column :pacientes, :reprocann_estado, :string, default: 'sin_registro', null: false
  end
end
