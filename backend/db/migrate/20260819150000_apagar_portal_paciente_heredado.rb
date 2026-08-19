class ApagarPortalPacienteHeredado < ActiveRecord::Migration[7.2]
  # `vista_paciente` sale de EN_CONSTRUCCION y pasa a ser un add-on que se vende. Mientras estaba
  # en construcción, `feature?` devolvía false para todos sin mirar lo guardado — así que nadie
  # notaba lo que tenía escrito en `features`.
  #
  # Al moverlo, dos cosas se prenderían solas el día del deploy: la bandera nueva si alguien la
  # guardó probando, y la VIEJA (`web_publica`), que `feature?` resuelve hacia la nueva. Ninguna
  # de las dos se cobró nunca. Se apagan las dos para que el estado sea explícito: lo tiene quien
  # lo contrate a partir de ahora.
  #
  # Es el backfill que pide toda migración que mueve un módulo de cajón. Sin él, el módulo
  # aparece regalado y después sacarlo es un problema con el cliente.
  def up
    Club.reset_column_information
    Club.find_each do |club|
      features = club.features || {}
      next unless features.key?('vista_paciente') || features.key?('web_publica')

      features.delete('web_publica')
      features['vista_paciente'] = false
      club.update_column(:features, features)
    end
  end

  def down
    # No se revierte: volver a prender un módulo que nadie contrató sería peor que el estado que
    # esta migración deja.
  end
end
