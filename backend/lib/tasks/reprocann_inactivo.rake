# «INACTIVO» NO ES UN ESTADO DEL REPROCANN (2-oct-2026).
#
# El formulario del paciente ofrecía Sin registro / Pendiente / Activo / Inactivo como estado del
# REPROCANN, y activo/inactivo es otra cosa: el paciente en la organización (el tilde «Activo»). Los
# estados del REPROCANN son sin registro, pendiente de aprobación y vigente; vencido sale de la fecha.
#
# Los que quedaron con `inactivo`:
#   · con número de REPROCANN → `activo` (vigente; si la fecha ya pasó, el sistema lo muestra vencido)
#   · sin número              → `sin_registro`
# El estado del PACIENTE (activo/inactivo en la organización) no se toca.
#
#   bundle exec rake reprocann:sin_inactivo              # sólo lista
#   bundle exec rake reprocann:sin_inactivo CONFIRMAR=1  # lo aplica
namespace :reprocann do
  desc 'Pasa los REPROCANN «inactivo» a vigente (con número) o sin registro (CONFIRMAR=1 para aplicar)'
  task sin_inactivo: :environment do
    ActsAsTenant.without_tenant do
      pacs = Paciente.unscoped.where(reprocann_estado: 'inactivo').order(:club_id, :id).to_a
      if pacs.empty?
        puts 'Ningún paciente tiene el REPROCANN en «inactivo».'
        next
      end

      nombres = Club.unscoped.where(id: pacs.map(&:club_id).uniq).pluck(:id, :name).to_h
      pacs.each do |p|
        nuevo = p.reprocann_numero.present? ? 'activo' : 'sin_registro'
        puts "  #{nombres[p.club_id]} · paciente ##{p.id} · REPROCANN #{p.reprocann_numero.presence || '(sin número)'} " \
             "vence #{p.reprocann_vencimiento || '—'} → #{nuevo == 'activo' ? 'vigente' : 'sin registro'}"
      end
      puts "\n#{pacs.size} paciente(s)."
      unless ENV['CONFIRMAR'].present?
        puts 'Sólo lectura. Corré con CONFIRMAR=1 para aplicarlo.'
        next
      end

      Paciente.transaction do
        pacs.each { |p| p.update_columns(reprocann_estado: p.reprocann_numero.present? ? 'activo' : 'sin_registro', updated_at: Time.current) }
      end
      puts "✓ #{pacs.size} paciente(s) corregidos."
    end
  end
end
