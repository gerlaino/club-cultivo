# Las plantillas de correo dejan de estar hardcodeadas en el frontend y pasan a ser de cada
# organización, editables por su admin.
#
# Hasta ahora vivían en `frontend/src/composables/useSocioCorreo.js` como funciones JS, y el
# backend sólo validaba el NOMBRE contra `MailEnviado::TIPOS`. O sea: la plantilla estaba de un
# lado y su validación del otro. Esto lo da vuelta.
#
# El cuerpo lleva variables tipo `{{nombre}}`, resueltas contra una LISTA BLANCA CERRADA en
# `PlantillaMail::VARIABLES`. Nunca ERB ni interpolación libre: es texto que escribe un usuario
# y evaluarlo sería ejecución de código en el servidor.
class CreatePlantillasMail < ActiveRecord::Migration[7.2]
  def change
    create_table :plantillas_mail do |t|
      t.references :club, null: false, foreign_key: true
      t.string  :nombre, null: false
      t.string  :asunto, null: false
      t.text    :cuerpo, null: false
      # Una plantilla apagada no se ofrece para enviar pero no se pierde: sirve para sacar de
      # circulación un texto de temporada sin tener que volver a escribirlo el año que viene.
      t.boolean :activa, null: false, default: true
      # Marca cuál es la de bienvenida, que es la única que se dispara sola (al aprobar el alta).
      # Es un booleano y no un enum de tipos porque el resto de las plantillas no tienen rol:
      # son textos que alguien elige a mano.
      t.boolean :bienvenida, null: false, default: false
      t.references :creada_por, foreign_key: { to_table: :users }
      t.datetime :deleted_at
      t.bigint   :deleted_by_id

      t.timestamps
    end

    add_index :plantillas_mail, :deleted_at
    # Dos plantillas con el mismo nombre en la misma organización son indistinguibles en el
    # selector. El índice ignora las borradas para que un nombre se pueda reutilizar.
    add_index :plantillas_mail, %i[club_id nombre], unique: true,
              where: 'deleted_at IS NULL', name: 'index_plantillas_mail_nombre_unico'
    # Una sola de bienvenida por organización: es la que se manda sola, y dos candidatas serían
    # un empate que resuelve el azar del orden de la query.
    add_index :plantillas_mail, :club_id, unique: true,
              where: 'bienvenida = true AND deleted_at IS NULL',
              name: 'index_plantillas_mail_una_bienvenida'

    # Con qué plantilla salió cada mail. Nullable: los mails libres no tienen ninguna, y los ya
    # enviados tampoco. `mails_enviados.tipo` queda intacto para no romper las filas viejas.
    add_reference :mails_enviados, :plantilla_mail, foreign_key: { to_table: :plantillas_mail }
  end
end
