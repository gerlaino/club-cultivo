class AddDeclaradaComoAGeneticas < ActiveRecord::Migration[7.2]
  # Los clubes cultivan genéticas que NO están inscriptas en el INASE, y la forma de
  # etiquetarlas es declararlas contra una variedad que sí lo está. Hoy eso se hace a mano
  # sobre la etiqueta y la app no se entera, así que el informe INASE muestra el nombre de
  # fantasía y "sin registrar", que no es lo que el club presenta.
  #
  # El vínculo apunta al catálogo global de variedades registradas (`geneticas` con
  # club_id NULL y registrada_inase = true): no se duplica por club.
  #
  # Nullable a propósito: declarar es opcional. Una genética sin declarar sigue funcionando
  # y aparece marcada como pendiente en el informe INASE.
  def change
    add_reference :geneticas, :declarada_como,
                  foreign_key: { to_table: :geneticas }, null: true, index: true
  end
end
