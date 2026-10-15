# La huella de un documento de paciente (`hash_documento`) deja de ser ÚNICA (15-oct-2026).
#
# Se calculaba sobre el texto del documento y un archivo subido tiene siempre el mismo texto,
# «(documento adjunto)»: el primer archivo de la plataforma se guardó y todos los siguientes,
# de cualquier organización, chocaban con el índice único y daban 500. Ahora la huella se calcula
# sobre el archivo (`PatientDocument#calcular_hash`), pero aun así no puede ser única: el mismo PDF
# se sube a dos pacientes, o se vuelve a subir después de borrarlo (la fila borrada la conserva).
# La huella prueba que un documento no cambió; no identifica al documento. Sigue indexada.
class HuellaDeDocumentoNoUnica < ActiveRecord::Migration[7.2]
  def up
    remove_index :patient_documents, name: 'index_patient_documents_on_hash_documento'
    add_index :patient_documents, :hash_documento
  end

  # Volver atrás sólo anda si no quedaron huellas repetidas.
  def down
    remove_index :patient_documents, :hash_documento
    add_index :patient_documents, :hash_documento, unique: true, where: 'hash_documento IS NOT NULL',
                                                   name: 'index_patient_documents_on_hash_documento'
  end
end
