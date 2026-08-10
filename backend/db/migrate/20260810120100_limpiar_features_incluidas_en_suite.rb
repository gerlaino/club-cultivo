class LimpiarFeaturesIncluidasEnSuite < ActiveRecord::Migration[7.2]
  # `medico` y `mailer` dejan de ser interruptores: vienen dentro de la suite de Producción y
  # dispensa. Los dos viven de la ficha del paciente, así que un club de sólo Cultivo —que no
  # tiene pacientes— no los ve nunca, y poder apagárselos a un club que sí la tiene era una
  # perilla que, olvidada, lo dejaba con media ficha.
  #
  # Se borran las claves guardadas para que quede UNA sola fuente: `Club#features_expandidas`
  # las deriva de la suite. Dejarlas habría permitido que digan lo contrario que su suite.
  #
  # `web_publica` también se borra: pasa a llamarse `vista_paciente` y queda EN CONSTRUCCIÓN
  # (ver Club::EN_CONSTRUCCION), así que hoy no habilita nada. `Club::FEATURES_LEGACY` mantiene
  # la equivalencia por si hay que volver.
  #
  # Antes de borrar, deja anotado en el log qué club pierde qué: si un club de sólo Cultivo
  # tenía el módulo médico prendido, esto se lo saca, y tiene que quedar rastro de cuál fue.

  CLAVES = %w[medico mailer web_publica].freeze

  def up
    afectados = select_all(<<~SQL).to_a
      SELECT id, name, features
      FROM clubs
      WHERE features ?| array['medico', 'mailer', 'web_publica']
    SQL

    afectados.each do |c|
      feats  = c['features'].is_a?(String) ? JSON.parse(c['features']) : c['features']
      tenia  = CLAVES.select { |k| feats[k] == true }
      pierde = tenia.include?('medico') && feats['produccion_dispensa'] != true
      next if tenia.empty?

      say "club ##{c['id']} (#{c['name']}): tenía #{tenia.join(', ')}" \
          "#{' — PIERDE el módulo médico: no tiene la suite de Producción y dispensa' if pierde}"
    end

    execute "UPDATE clubs SET features = features - 'medico' - 'mailer' - 'web_publica'"
  end

  def down
    # Devuelve las claves derivándolas de la suite, que es de donde salían.
    execute <<~SQL
      UPDATE clubs
      SET features = features || '{"medico": true, "mailer": true}'::jsonb
      WHERE features->>'produccion_dispensa' = 'true'
    SQL
  end
end
