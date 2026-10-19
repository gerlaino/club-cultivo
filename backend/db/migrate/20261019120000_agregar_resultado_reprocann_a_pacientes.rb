# «NO INDICADO» Y «RECHAZADO» (Germán, 19-oct-2026): la médica decide no pedir el REPROCANN, o el
# Ministerio rechaza el trámite. El paciente queda inactivo (no retira) y hay que guardar POR QUÉ y
# CUÁNDO: es lo que se lee al volver a entrevistarlo. El motivo va cifrado (puede ser clínico).
class AgregarResultadoReprocannAPacientes < ActiveRecord::Migration[7.2]
  def change
    add_column :pacientes, :reprocann_resultado_motivo, :text
    add_column :pacientes, :reprocann_resultado_el, :date
  end
end
