# Un paciente cargado desde el mostrador entra como SOLICITUD, no como alta.
#
# Dar de alta a alguien es una decisión de admisión —verificar el REPROCANN contra el
# certificado, el consentimiento de datos de salud, la cuota— y no trabajo de mostrador con la
# persona esperando adelante. Pero tampoco se puede mandar de vuelta a quien llega: el
# dispensador y el supervisor cargan la ficha, y admin o médico la aprueban antes de que se le
# pueda dispensar.
#
# `aprobado_at` nulo = pendiente. Se guarda también QUIÉN aprobó: es una decisión con
# consecuencias regulatorias y tiene que quedar el rastro.
class AddAprobacionAPacientes < ActiveRecord::Migration[7.2]
  def up
    add_column :pacientes, :aprobado_at,     :datetime
    add_column :pacientes, :aprobado_por_id, :bigint
    add_foreign_key :pacientes, :users, column: :aprobado_por_id
    add_index :pacientes, :aprobado_at

    # LO MÁS IMPORTANTE DE ESTA MIGRACIÓN: todos los pacientes que ya existen quedan aprobados.
    # Sin este backfill, el día del deploy ningún paciente del padrón podría recibir una
    # dispensación —la validación nueva los vería a todos como pendientes— y el mostrador de
    # cada organización se frenaría entero.
    #
    # `created_at` y no `Time.current`: la fecha honesta de admisión es cuando entró, no cuando
    # corrimos la migración.
    execute <<~SQL
      UPDATE pacientes SET aprobado_at = created_at WHERE aprobado_at IS NULL
    SQL
  end

  def down
    remove_foreign_key :pacientes, column: :aprobado_por_id
    remove_column :pacientes, :aprobado_por_id
    remove_column :pacientes, :aprobado_at
  end
end
