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

    # `Auditoria` es acts_as_tenant y con require_tenant=true (TEN-01c) una escritura sin tenant
    # fijado explota. Eso dejaba SIN RASTRO justo las acciones que más falta hacía registrar:
    # las del super admin, que opera cross-club y corre sin tenant a propósito.
    #
    # Se fija el tenant SÓLO cuando no hay ninguno. Envolver siempre tenía un efecto lateral
    # feo: `with_tenant`/`without_tenant` releen `current_tenant` —que incluye el `test_tenant`
    # de los specs— y al salir lo escriben en `Current.current_tenant`, que no se limpia entre
    # ejemplos; el spec siguiente heredaba un club cuya transacción ya se había revertido y
    # fallaba con "Club es obligatorio".
    if ActsAsTenant.current_tenant
      crear_auditoria(accion, cambios)
    else
      ActsAsTenant.with_tenant(club_para_auditoria) { crear_auditoria(accion, cambios) }
    end
  rescue => e
    # La auditoría nunca debe tumbar la operación de negocio
    Rails.logger.error "[Auditable] No se pudo registrar auditoría de #{self.class.name}##{id}: #{e.message}"
  end

  def crear_auditoria(accion, cambios)
    Auditoria.create!(
      auditable_type: self.class.name,
      auditable_id:   id,
      club_id:        club_id,
      user:           Current.user,
      accion:         accion,
      cambios:        cambios,
    )
  end

  # El club contra el que se guarda el rastro. Para el propio Club es él mismo, así se evita
  # una consulta de más en el caso más común de este camino.
  def club_para_auditoria
    is_a?(Club) ? self : Club.find_by(id: club_id)
  end
end
