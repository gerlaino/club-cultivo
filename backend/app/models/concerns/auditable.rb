# Registra cada create/update/destroy del modelo en la tabla auditorias,
# con el usuario del request (Current.user) y el detalle de los cambios.
# El modelo debe responder a club_id.
#
# Para excluir campos ruidosos (contadores de cache, timestamps derivados) del rastro:
#   class Lote < ApplicationRecord
#     include Auditable
#     no_auditar :plants_count
#   end
module Auditable
  extend ActiveSupport::Concern

  included do
    # updated_at siempre fuera (cambia en cada save y no aporta). Los modelos suman lo suyo.
    class_attribute :campos_no_auditables, instance_writer: false, default: %w[updated_at]

    after_create  { registrar_auditoria('crear',      attributes.except(*campos_no_auditables)) }
    after_update  { registrar_auditoria('actualizar', saved_changes.except(*campos_no_auditables)) }
    after_destroy { registrar_auditoria('eliminar',   attributes.except(*campos_no_auditables)) }
  end

  class_methods do
    # Campos que NO se registran (contadores de cache, timestamps, ruido).
    def no_auditar(*campos)
      self.campos_no_auditables = (campos_no_auditables + campos.map(&:to_s)).uniq
    end
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
