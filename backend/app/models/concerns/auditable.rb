# Registra cada create/update/destroy del modelo en la tabla auditorias,
# con el usuario del request (Current.user) y el detalle de los cambios.
# El modelo debe responder a club_id.
module Auditable
  extend ActiveSupport::Concern

  included do
    after_create  { registrar_auditoria('crear',      attributes) }
    after_update  { registrar_auditoria('actualizar', saved_changes.except('updated_at')) }
    after_destroy { registrar_auditoria('eliminar',   attributes) }
  end

  private

  def registrar_auditoria(accion, cambios)
    return if accion == 'actualizar' && cambios.blank?

    Auditoria.create!(
      auditable_type: self.class.name,
      auditable_id:   id,
      club_id:        club_id,
      user:           Current.user,
      accion:         accion,
      cambios:        cambios,
    )
  rescue => e
    # La auditoría nunca debe tumbar la operación de negocio
    Rails.logger.error "[Auditable] No se pudo registrar auditoría de #{self.class.name}##{id}: #{e.message}"
  end
end
