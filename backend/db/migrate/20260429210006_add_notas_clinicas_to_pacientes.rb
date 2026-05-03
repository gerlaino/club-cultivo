class AddNotasClinicasToPacientes < ActiveRecord::Migration[7.1]
  def up
    add_column :pacientes, :notas_clinicas, :text
  end

  def down
    remove_column :pacientes, :notas_clinicas
  end
end
