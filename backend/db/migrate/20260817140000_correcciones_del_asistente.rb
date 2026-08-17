# Qué propuso el asistente y qué terminó confirmando la persona.
#
# Hoy esa corrección se tira. Sin ella no hay forma de contestar dos preguntas que valen mucho:
#
#   1. **¿Qué tan bien interpreta?** Medido, no supuesto. Hoy la única evidencia de que el
#      dictado anda es que nadie se quejó.
#   2. **¿Cómo habla ESTA organización?** "Dos pulsos" son cuatro litros en un club y otra cosa
#      en otro. Con el histórico de correcciones se le pueden dar ejemplos propios del club, y
#      ahí el asistente deja de ser un formulario con micrófono y empieza a conocer a su gente.
#
# Se guarda al PARSEAR, no al ejecutar: un dictado que se propuso y nadie usó también es señal
# —el modelo propuso algo que no servía— y si esperáramos al guardado, ese caso se perdería.
# `confirmado` se completa después, cuando y si la persona guarda.
#
# `texto` es lo que se dictó. Son notas de cultivo, no datos clínicos, pero es texto de una
# persona: vive bajo el tenant como todo lo demás y se borra con la organización.
class CorreccionesDelAsistente < ActiveRecord::Migration[7.2]
  def change
    create_table :asistente_correcciones do |t|
      t.references :club, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.text  :texto, null: false                       # lo que se dictó, tal cual
      t.jsonb :propuesto,  null: false, default: {}      # lo que devolvió el modelo
      t.jsonb :confirmado, null: false, default: {}      # lo que la persona terminó guardando

      # Se completa al guardar. Nulo = se dictó y nunca se ejecutó (se canceló, o se volvió a
      # grabar), que es su propia señal y no hay que confundirla con "no cambió nada".
      t.boolean  :hubo_correccion
      t.datetime :ejecutado_en

      t.timestamps
    end

    # La consulta que importa es "cómo viene esta organización en el último tiempo".
    add_index :asistente_correcciones, %i[club_id created_at]
  end
end
