# Avisa por ActionCable, después de cada commit, que este registro cambió — para que las
# pantallas abiertas se actualicen sin recargar (pedido de Germán, 20-sep-2026: «si registro
# eventos debe verse reflejado en todos lados, así como los movimientos de stock, mostrador»).
#
#   class Stock < ApplicationRecord
#     include Transmite
#     transmite_como 'stocks'                 # el recurso que el frontend conoce
#   end
#
# Formato único: `{ recurso, accion, id, sede_id, por, at }`. `accion` es creado / actualizado /
# borrado (la baja lógica de paranoia cuenta como borrado). No viaja el dato: quien escucha
# re-pide lo que muestra; así la pantalla siempre ve lo que el backend serializa para ella (con
# sus permisos y su tenant) y no un payload armado a mano que después se desactualiza.
#
# Nunca rompe el guardado: un cable caído se loguea y listo.
module Transmite
  extend ActiveSupport::Concern

  included do
    class_attribute :recurso_transmitido, instance_writer: false, default: nil
    after_commit :transmitir_cambio
  end

  class_methods do
    def transmite_como(recurso) = self.recurso_transmitido = recurso.to_s
  end

  def transmitir_cambio
    return if recurso_transmitido.blank? || !respond_to?(:club_id) || club_id.blank?

    Transmite.emitir(club_id, recurso: recurso_transmitido, accion: accion_transmitida, id: id,
                     sede_id: (respond_to?(:sede_id) ? sede_id : nil))
  end

  # También sirve suelto, para lo que cambia sin pasar por un modelo (un rake, un servicio).
  def self.emitir(club_id, recurso:, accion:, id: nil, sede_id: nil)
    ActionCable.server.broadcast("club_#{club_id}", {
      recurso: recurso.to_s, accion: accion.to_s, id: id, sede_id: sede_id,
      por: Current.user&.id, at: Time.current.iso8601(3),
    })
  rescue => e
    Rails.logger.warn("[Transmite] #{recurso} #{accion} #{id}: #{e.class} #{e.message}")
  end

  private

  def accion_transmitida
    return 'borrado' if destroyed?
    # Paranoia pone `deleted_at` con `update_columns` (sin rastro en `saved_changes`) y no marca
    # `destroyed?`: si está fechado, está borrado.
    return 'borrado' if respond_to?(:deleted_at) && deleted_at.present?
    return 'creado'  if previously_new_record?
    'actualizado'
  end
end
