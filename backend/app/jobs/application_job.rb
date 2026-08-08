class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  # ── Recorrer clubes desde un job ──────────────────────────────────────────
  #
  #   cada_club_con(:produccion_dispensa) { |club| ... }
  #
  # Los jobs corren fuera de un request: no hay `current_user`, no pasan por
  # `check_club_activo!` ni por `require_feature!`. Sin esto, un club que apagó un módulo —o que
  # directamente se dio de baja— seguía recibiendo sus alertas, sus push y sus mails. El aviso
  # de vencimiento de REPROCANN le llegaba al PACIENTE, no al club: no es ruido interno.
  #
  # Resuelve las tres cosas que cada job repetía a mano (o se olvidaba):
  #   1. sólo clubes operativos (ni eliminados ni suspendidos),
  #   2. sólo los que tienen prendida la suite/add-on del que depende el job,
  #   3. `with_tenant` + rescue por club, para que uno que explota no corte la tanda.
  #
  # `clave` puede ser una suite o un add-on; con varias, alcanza con que UNA esté prendida.
  # Sin clave, recorre todos los clubes operativos (jobs de infraestructura).
  def cada_club_con(*claves, scope: Club.operativos)
    scope.find_each do |club|
      next if claves.any? && claves.none? { |c| club.feature?(c) }

      ActsAsTenant.with_tenant(club) { yield club }
    rescue StandardError => e
      Rails.logger.error "#{self.class.name}: club #{club.id} falló: #{e.class}: #{e.message}"
    end
  end
end
