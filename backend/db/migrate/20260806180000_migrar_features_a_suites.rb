class MigrarFeaturesASuites < ActiveRecord::Migration[7.2]
  # Reagrupa las 13 banderas sueltas en 2 suites + add-ons.
  #
  # Lo IMPORTANTE de esta migración es que ningún club existente pierda acceso a algo que hoy
  # está usando. Por eso se activa lo que ya venía activo (o lo que es núcleo y nunca debió
  # poder apagarse), y sólo se apaga lo que directamente no funciona.
  def up
    Club.reset_column_information

    Club.unscoped.find_each do |club|
      f = (club.features || {}).dup

      # Las dos suites: todos los clubes actuales operan cultivo y dispensa. Apagárselas ahora
      # sería sacarles la app entera; si alguno debe tener sólo una, se ajusta a mano después.
      f['cultivo']             = true
      f['produccion_dispensa'] = true

      # IA: antes eran dos flags separados, ahora uno.
      f['ia'] = true if f['ia_analisis'] == true || f['ia_voz'] == true

      # El módulo médico NUNCA fue un flag: estaba siempre disponible. Se activa para no
      # quitárselo a quien lo usa (turnos, historia clínica, indicaciones).
      f['medico'] = true unless f.key?('medico')

      # WhatsApp tampoco era flag: se activa sólo si el club tiene Twilio configurado de verdad.
      f['whatsapp'] = true if club.respond_to?(:whatsapp_configurado?) && club.whatsapp_configurado?

      # Los incompletos se apagan: la web pública no está deployada, ARICCAME está SIMULADO
      # (no transmite nada a ANMAT) y los eventos todavía no están pulidos. Dejarlos prendidos
      # es prometer algo que no ocurre.
      f['web_publica'] = false
      f['ariccame']    = false
      f['eventos']     = false

      # Las que dejan de ser banderas: son núcleo de sus suites y no tenía sentido apagarlas
      # por separado. Se borran para que el panel no muestre casillas que no hacen nada.
      %w[ia_analisis ia_voz cuenta_corriente analytics multi_sede insumos alertas].each { |k| f.delete(k) }

      club.update_columns(features: f)
    end
  end

  def down
    Club.reset_column_information

    Club.unscoped.find_each do |club|
      f = (club.features || {}).dup
      f['ia_analisis']      = true if f['ia'] == true
      f['ia_voz']           = true if f['ia'] == true
      f['cuenta_corriente'] = true
      f['analytics']        = true
      f['multi_sede']       = true
      f['insumos']          = true
      f['alertas']          = true
      %w[cultivo produccion_dispensa ia medico whatsapp].each { |k| f.delete(k) }
      club.update_columns(features: f)
    end
  end
end
