# frozen_string_literal: true

# Ver `lib/tasks/preprod.rake` para el porqué de todo esto y cómo se usa.
#
# La clase vive aparte de la tarea para poder verificarla con un spec: el que barre la base entera
# buscando rastros de la persona real es lo que hace confiable el proceso.
module Preprod
  class Anonimizador
    def initialize(simular:)
      @simular = simular
      @total   = 0
    end

    def ejecutar!
      # El orden importa: los canales primero. Si algo revienta en el medio, revienta con
      # preproducción ya incapaz de contactar a nadie.
      cortar_canales!
      anonimizar_personas!
      borrar_texto_libre!

      puts "\n#{@simular ? '· Simulación terminada' : "✓ Listo"}: #{@total} filas #{@simular ? 'se tocarían' : 'reescritas'}.\n"
      return if @simular

      puts "  Recordá que las contraseñas quedaron sin cambiar: corré"
      puts "  `rake seguridad:usuarios_con_password_default` y reseteá las que necesites usar.\n\n"
    end

    private

    # ── 1. Cortar los canales hacia personas reales ──────────────────────────
    def cortar_canales!
      titulo 'Cortando los canales a personas reales'

      # La casilla de la organización. Sin esto, un envío masivo de prueba sale de verdad.
      ejecutar 'clubs: casilla SMTP', <<~SQL
        UPDATE clubs SET smtp_host = NULL, smtp_user = NULL, smtp_pass = NULL,
                         smtp_from = NULL, smtp_from_name = NULL
      SQL

      ejecutar 'clubs: credenciales de Twilio y WhatsApp', <<~SQL
        UPDATE clubs SET twilio_account_sid = NULL, twilio_auth_token_enc = NULL,
                         twilio_whatsapp_from = NULL, whatsapp_numero = NULL,
                         whatsapp = NULL, pulse_api_key_enc = NULL
      SQL

      # Un webhook apuntando al ERP real del cliente le mandaría eventos de prueba.
      ejecutar 'webhooks: apagados y apuntando a ninguna parte', <<~SQL
        UPDATE webhooks SET active = false, url = 'https://ejemplo.invalido/webhook',
                            secret = 'preprod'
      SQL

      # Los tokens de push son de CELULARES REALES. Se borran, no se anonimizan: un endpoint
      # inventado no sirve para nada y uno real le vibra el teléfono a un paciente.
      ejecutar 'push_subscriptions: borradas', 'DELETE FROM push_subscriptions'

      # El historial de correo trae el cuerpo de mails que se le mandaron a pacientes reales.
      ejecutar 'mails_enviados: borrados',  'DELETE FROM mails_enviados'
      ejecutar 'envios_masivos: borrados',  'DELETE FROM envios_masivos'
    end

    # ── 2. La identidad de las personas ──────────────────────────────────────
    #
    # Se reemplaza de forma DETERMINÍSTICA a partir del id: el mismo paciente es siempre "Paciente
    # 214". Así un bug que se reproduce hoy se sigue reproduciendo mañana, y se puede hablar de
    # "el 214" entre dos corridas del clon.
    def anonimizar_personas!
      titulo 'Anonimizando personas'

      ejecutar 'pacientes: nombre, DNI, contacto', <<~SQL
        UPDATE pacientes SET
          nombre          = 'Paciente',
          apellido        = 'N' || id,
          dni             = (90000000 + id)::text,
          dni_normalizado = (90000000 + id)::text,
          email           = 'paciente' || id || '@ejemplo.invalido',
          telefono        = '11' || LPAD((id % 100000000)::text, 8, '0')
      SQL

      # `users` queda fuera de acts_as_tenant y mezcla operadores con cuentas de pacientes. El
      # email se conserva en FORMA pero no en contenido: el login del portal deriva del nombre, y
      # romper el formato dejaría cuentas que no se pueden usar para probar.
      ejecutar 'users: nombre y contacto', <<~SQL
        UPDATE users SET
          first_name     = COALESCE(NULLIF(role, ''), 'Usuario'),
          last_name      = 'N' || id,
          dni            = (80000000 + id)::text,
          phone          = '11' || LPAD((id % 100000000)::text, 8, '0'),
          email_personal = NULL,
          email          = CASE
                             WHEN email LIKE '%@%.paciente' THEN 'paciente' || id || '@preprod.paciente'
                             ELSE split_part(email, '@', 1) || id || '@preprod.invalido'
                           END
        WHERE role <> 'super_admin'
      SQL

      # Los datos de entrega son domicilios de personas reales, y la firma es una imagen de una
      # firma de verdad.
      ejecutar 'dispensaciones: domicilio de entrega y firma', <<~SQL
        UPDATE dispensaciones SET
          direccion_envio   = CASE WHEN direccion_envio IS NULL THEN NULL ELSE 'Calle Falsa 123' END,
          envio_calle       = CASE WHEN envio_calle IS NULL THEN NULL ELSE 'Calle Falsa' END,
          envio_altura      = CASE WHEN envio_altura IS NULL THEN NULL ELSE '123' END,
          envio_piso        = NULL,
          envio_depto       = NULL,
          envio_barrio      = CASE WHEN envio_barrio IS NULL THEN NULL ELSE 'Barrio' END,
          envio_ciudad      = CASE WHEN envio_ciudad IS NULL THEN NULL ELSE 'Ciudad' END,
          contacto_nombre   = CASE WHEN contacto_nombre IS NULL THEN NULL ELSE 'Contacto' END,
          contacto_telefono = CASE WHEN contacto_telefono IS NULL THEN NULL ELSE '1100000000' END,
          firma_entrega_data = NULL,
          historial_envio   = '[]'::jsonb
      SQL

      # El registro de auditoría guarda los cambios campo por campo: adentro hay nombres, DNI y
      # mails tal como estaban. Se conserva la FILA (quién tocó qué y cuándo, que es lo que se
      # prueba) y se vacía el contenido.
      ejecutar 'auditorias: contenido de los cambios', <<~SQL
        UPDATE auditorias SET cambios = '{}'::jsonb
      SQL
    end

    # ── 3. El texto libre: lo clínico y lo que se escribe a mano ─────────────
    #
    # Acá no se puede anonimizar "por campo": es prosa escrita por una persona, y adentro puede
    # haber cualquier cosa —un nombre, un teléfono, un diagnóstico—. Se vacía.
    #
    # Los campos de `indicacion_medicas` están ENCRIPTADOS con las claves de producción. Se pisan
    # con texto plano, que Rails lee igual porque `support_unencrypted_data = true`.
    def borrar_texto_libre!
      titulo 'Vaciando el texto libre y lo clínico'

      ejecutar 'indicacion_medicas: patología, dosis, vía y observaciones', <<~SQL
        UPDATE indicacion_medicas SET
          patologia          = 'Patología de prueba',
          dosificacion       = '2 gotas cada 12 horas',
          via_administracion = 'sublingual',
          observaciones      = NULL
      SQL

      ejecutar 'turnos: motivo y notas del médico', <<~SQL
        UPDATE turnos SET motivo = NULL, notas_post = NULL
      SQL

      ejecutar 'paciente_notas: contenido',        "UPDATE paciente_notas SET contenido = 'Nota de prueba'"
      ejecutar 'resenas_producto: comentario',     'UPDATE resenas_producto SET comentario = NULL'
      ejecutar 'check_ins: notas',                 'UPDATE check_ins SET notas = NULL'
      ejecutar 'dispensaciones: observaciones y notas de entrega', <<~SQL
        UPDATE dispensaciones SET observaciones = NULL, notas_envio = NULL,
                                  notas_entrega = NULL, motivo_fallo = NULL
      SQL
      ejecutar 'documentos: título y descripción', <<~SQL
        UPDATE documentos SET titulo = 'Documento de prueba', descripcion = NULL
      SQL
      ejecutar 'reprocann_renovaciones: trámite y observaciones', <<~SQL
        UPDATE reprocann_renovaciones SET numero_tramite = NULL, observaciones = NULL
      SQL
      ejecutar 'cuenta_corriente_movimientos: descripción', <<~SQL
        UPDATE cuenta_corriente_movimientos SET descripcion = NULL
      SQL
      ejecutar 'alertas_internas: mensaje', <<~SQL
        UPDATE alertas_internas SET mensaje = 'Alerta de prueba', contexto = '{}'::jsonb
      SQL
    end

    # ── Plomería ─────────────────────────────────────────────────────────────

    def titulo(txt)
      puts "\n── #{txt} ──"
    end

    def ejecutar(etiqueta, sql)
      tabla = sql[/(?:UPDATE|DELETE FROM)\s+(\w+)/i, 1]

      if @simular
        n = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{tabla}").to_i
        @total += n
        puts format('  · %-52s %6d filas', etiqueta, n)
      else
        n = ActiveRecord::Base.connection.execute(sql).cmd_tuples
        @total += n
        puts format('  ✓ %-52s %6d filas', etiqueta, n)
      end
    end
  end
end
