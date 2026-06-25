# ENC-01 — Backfill de cifrado at-rest.
#
# Re-cifra in situ los datos sensibles que ya existen en texto plano. Pensado para
# correrse UNA vez en producción después de deployar el cifrado, mientras
# `support_unencrypted_data = true` (config en application.rb) permite leer lo viejo.
#
# Es idempotente y seguro de re-correr: una fila ya cifrada se vuelve a cifrar sin
# pérdida. Usa save!(validate: false) para no fallar con filas legacy que no pasen
# las validaciones actuales (sí bumpea updated_at — efecto esperado de una migración).
#
# Después de correrlo y verificar, en una deploy posterior poner
# support_unencrypted_data = false para endurecer (rechazar texto plano).
#
#   docker compose exec backend bundle exec rails encryption:backfill
namespace :encryption do
  desc "ENC-01: re-cifra in situ los datos sensibles existentes (idempotente)"
  task backfill: :environment do
    specs = {
      "Paciente" => %w[
        dni dni_normalizado reprocann_numero email telefono
        notas_clinicas motivo_consulta anamnesis antecedentes_personales
        antecedentes_familiares diagnostico_principal diagnostico_secundario
        evolucion_clinica alergias medicacion_habitual grupo_sanguineo
      ],
      "IndicacionMedica" => %w[patologia dosificacion via_administracion observaciones],
      "PatientDocument"  => %w[contenido_html firma_paciente_dni firma_medico_dni],
      "User"             => %w[dni phone],
    }

    specs.each do |model_name, attrs|
      model = model_name.constantize
      # Incluir soft-deleted (paranoia): esos datos sensibles también deben cifrarse.
      relation = model.respond_to?(:with_deleted) ? model.with_deleted : model.unscoped
      total = relation.count
      puts "== #{model_name}: #{total} filas =="
      done = 0
      relation.find_each(batch_size: 200) do |rec|
        changed = false
        attrs.each do |attr|
          next if rec.public_send(attr).nil?
          rec.public_send("#{attr}_will_change!") # forzar reescritura (mismo valor → cifrado)
          changed = true
        end
        rec.save!(validate: false) if changed
        done += 1
        puts "   #{done}/#{total}" if (done % 1000).zero?
      end
      puts "   ✓ #{model_name} re-cifrado"
    end

    puts "Backfill completo. Próximo paso (deploy posterior): support_unencrypted_data = false."
  end
end
