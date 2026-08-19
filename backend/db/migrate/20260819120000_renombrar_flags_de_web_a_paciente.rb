# Los flags dejan de decir "web" porque ya no hay web.
#
# `genetica.visible_web` y `club.web_activa` nacieron para un sitio público por club. Ese sitio
# se retiró: lo que la organización muestra vive ahora detrás del login del paciente. Los nombres
# quedaron mintiendo — "visible_web" ya no significa "visible en internet" sino "visible para mis
# pacientes", que es casi lo contrario en materia de privacidad.
#
# Se renombran ahora y no después: un nombre que miente es de lo que más cuesta desenredar seis
# meses más tarde, cuando alguien lo lea y asuma lo que dice.
class RenombrarFlagsDeWebAPaciente < ActiveRecord::Migration[7.2]
  def change
    rename_column :geneticas, :visible_web,  :visible_paciente
    rename_column :clubs,     :web_activa,   :vista_paciente_activa
  end
end
