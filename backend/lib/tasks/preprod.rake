# frozen_string_literal: true

# ─────────────────────────────────────────────────────────────────────────────
# Anonimizar una copia de producción para poder usarla en PREPRODUCCIÓN.
#
# El problema que resuelve: con datos inventados no aparecen los bugs que importan. Los que
# aparecen son los de VOLUMEN y los de datos raros —el paciente con dos REPROCANN, el lote con la
# fase mal, el nombre con apóstrofe—, y nada de eso lo genera un seed.
#
# Entonces se restaura el dump de producción tal cual (`pg_restore`) y después se corre esto, que
# reemplaza SÓLO la identidad de las personas. Todo lo demás —fechas, cantidades, pesos, códigos de
# lote, movimientos, relaciones— queda intacto, que es justamente lo que hace aparecer los bugs.
#
# ── Lo que casi nadie mira, y es lo más peligroso ────────────────────────────
#
# Una copia de producción no trae sólo datos: trae CANALES ABIERTOS a personas reales.
#
#   `clubs.smtp_pass`            → preproducción manda mails DESDE la casilla real de la
#                                  organización, a las casillas reales de sus pacientes
#   `clubs.twilio_auth_token_enc`→ manda WhatsApp de verdad
#   `webhooks.url` + `secret`    → le pega al sistema externo real del cliente
#   `push_subscriptions`         → le llegan notificaciones al celular del paciente
#
# Un ambiente de pruebas con eso adentro le puede mandar un WhatsApp a un paciente real un martes a
# las tres de la mañana. Por eso el orden de esta tarea es: **primero cortar los canales, después
# anonimizar**. Si algo falla en el medio, falla con los canales ya cortados.
#
# ── Por qué SQL crudo y no ActiveRecord ──────────────────────────────────────
#
# Preproducción tiene claves de cifrado DISTINTAS de producción (ver docs/DEPLOY.md §4). Los campos
# encriptados —patología, dosificación, vía, observaciones de `indicacion_medicas`— vienen cifrados
# con las claves de producción, así que si Rails intenta LEERLOS revienta. En SQL se pisan sin
# leerlos. Es la única forma de que esto funcione.
#
# ── Uso ──────────────────────────────────────────────────────────────────────
#
#   rake preprod:anonimizar SIMULAR=1              # muestra qué haría, no toca nada
#   rake preprod:anonimizar CONFIRMO_BASE=<nombre> # lo hace
#
# El nombre de la base hay que tipearlo a mano y tiene que coincidir con la base conectada. Es a
# propósito: pegar el comando en la consola equivocada no puede terminar en un desastre.
# ─────────────────────────────────────────────────────────────────────────────

require Rails.root.join('lib/preprod/anonimizador')

namespace :preprod do
  desc 'Anonimiza una copia de producción para usarla en preproducción. SIMULAR=1 para ver qué haría.'
  task anonimizar: :environment do
    simular = ENV['SIMULAR'].present?
    base    = ActiveRecord::Base.connection.current_database

    puts "\n  Base conectada: #{base}"
    puts "  Modo: #{simular ? 'SIMULACIÓN (no se toca nada)' : 'REAL'}\n\n"

    unless simular
      confirmada = ENV['CONFIRMO_BASE'].to_s.strip
      if confirmada != base
        abort "✗ Abortado. Esto REESCRIBE datos y no se puede deshacer.\n" \
              "  Para confirmar que estás en la base correcta:\n\n" \
              "    rake preprod:anonimizar CONFIRMO_BASE=#{base}\n\n" \
              "  Si esta base es PRODUCCIÓN, no corras esto."
      end
    end

    Preprod::Anonimizador.new(simular: simular).ejecutar!
  end
end
