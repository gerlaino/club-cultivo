class RenameSociosToPacientes < ActiveRecord::Migration[7.2]
  def up
    rename_table  :socios,      :pacientes
    rename_table  :socio_notas, :paciente_notas

    rename_column :dispensaciones,    :socio_id, :paciente_id
    rename_column :paciente_notas,    :socio_id, :paciente_id
    rename_column :patient_documents, :socio_id, :paciente_id
    rename_column :cuenta_corrientes, :socio_id, :paciente_id
    rename_column :indicacion_medicas,:socio_id, :paciente_id
    rename_column :socio_nota,        :socio_id, :paciente_id

    execute "UPDATE users SET role = 'paciente' WHERE role = 'socio'"
  end

  def down
    execute "UPDATE users SET role = 'socio' WHERE role = 'paciente'"

    rename_column :socio_nota,        :paciente_id, :socio_id
    rename_column :indicacion_medicas,:paciente_id, :socio_id
    rename_column :cuenta_corrientes, :paciente_id, :socio_id
    rename_column :patient_documents, :paciente_id, :socio_id
    rename_column :paciente_notas,    :paciente_id, :socio_id
    rename_column :dispensaciones,    :paciente_id, :socio_id

    rename_table  :paciente_notas, :socio_notas
    rename_table  :pacientes,      :socios
  end
end
