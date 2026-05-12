class AddHistoriaClinicaToPacientes < ActiveRecord::Migration[7.2]
  def change
    add_column :pacientes, :motivo_consulta,          :text
    add_column :pacientes, :anamnesis,                :text
    add_column :pacientes, :antecedentes_personales,  :text
    add_column :pacientes, :antecedentes_familiares,  :text
    add_column :pacientes, :diagnostico_principal,    :string
    add_column :pacientes, :diagnostico_secundario,   :string
    add_column :pacientes, :evolucion_clinica,        :text
    add_column :pacientes, :alergias,                 :text
    add_column :pacientes, :medicacion_habitual,      :text
    add_column :pacientes, :grupo_sanguineo,          :string, limit: 5
  end
end
