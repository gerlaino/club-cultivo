# `mailer` dejó de ser un módulo DERIVADO de la suite de Producción y dispensa y pasa a ser un
# add-on contratable, con su propio espacio (casilla, plantillas y envíos).
#
# El backfill NO es opcional. Al ser derivado, `feature?('mailer')` devolvía true para toda
# organización con la suite y no había NADA guardado en `features`. Sin este UPDATE, el día del
# deploy todas se quedarían sin correo de un momento a otro: la solapa desaparece y los mails a
# pacientes dejan de poder enviarse. Es el mismo caso que Delivery.
#
# Se prende para quien tenga la suite, que es exactamente quién lo tenía ayer. Darlo de baja
# después es una decisión comercial, no un efecto secundario de esta migración.
class MailerPasaAAddon < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      UPDATE clubs
         SET features = features || '{"mailer": true}'::jsonb
       WHERE features ->> 'produccion_dispensa' = 'true'
         AND features ->> 'mailer' IS DISTINCT FROM 'true'
    SQL
  end

  # Volver atrás es sacar la clave: si `mailer` vuelve a INCLUIDOS_EN_SUITE se deriva sola, y
  # dejar el `true` guardado sería una segunda fuente que se contradice con la suite.
  def down
    execute <<~SQL
      UPDATE clubs SET features = features - 'mailer'
    SQL
  end
end
