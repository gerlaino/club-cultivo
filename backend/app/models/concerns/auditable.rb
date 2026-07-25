# Registra cada create/update/destroy del modelo en la tabla auditorias,
# con el usuario del request (Current.user) y el detalle de los cambios.
# El modelo debe responder a club_id.
#
# Para excluir campos ruidosos (contadores de cache, timestamps derivados) del rastro:
#   class Lote < ApplicationRecord
#     include Auditable
#     no_auditar :plants_count           # denylist: todo menos estos
#   end
#
# Para modelos con datos sensibles (ej. Paciente con campos clínicos), conviene ALLOWLIST —
# auditar SOLO campos explícitos, así una columna nueva no se filtra por olvido:
#   class Paciente < ApplicationRecord
#     include Auditable
#     auditar_solo :nombre, :reprocann_numero, ...
#   end
module Auditable
  extend ActiveSupport::Concern

  included do
    # updated_at siempre fuera (cambia en cada save y no aporta). Los modelos suman lo suyo.
    class_attribute :campos_no_auditables, instance_writer: false, default: %w[updated_at]
    # nil = auditar todo (menos no_auditables). Si se setea, auditar SOLO estos (allowlist).
    class_attribute :campos_auditables_solo, instance_writer: false, default: nil

    after_create  { registrar_auditoria('crear',      filtrar_campos(attributes)) }
    after_update  { registrar_auditoria('actualizar', filtrar_campos(saved_changes)) }
    after_destroy { registrar_auditoria('eliminar',   filtrar_campos(attributes)) }
  end

  class_methods do
    # Denylist: campos que NO se registran (contadores de cache, timestamps, ruido).
    def no_auditar(*campos)
      self.campos_no_auditables = (campos_no_auditables + campos.map(&:to_s)).uniq
    end

    # Allowlist: audita SOLO estos campos. Para datos sensibles (privacidad): lo no listado nunca
    # se guarda, aunque se agregue una columna nueva.
    def auditar_solo(*campos)
      self.campos_auditables_solo = campos.map(&:to_s)
    end
  end

  private

  def filtrar_campos(hash)
    filtrado = hash.except(*campos_no_auditables)
    filtrado = filtrado.slice(*campos_auditables_solo) if campos_auditables_solo
    filtrado
  end

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
