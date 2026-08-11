# Apaga los módulos cuya baja ya venció.
#
# La baja de un módulo se programa para el fin del período pago: hasta esa fecha la organización
# lo sigue usando igual, porque ya lo pagó. Este job corre una vez por día y aplica las que
# llegaron a término.
#
# No cuenta como el guardián de la regla: `Club#feature?` ya devuelve false apenas la fecha pasa,
# así que entre el vencimiento y la corrida del job nadie puede usar el módulo. Lo que hace el
# job es dejar el estado prolijo —bajar la bandera— y ejecutar la limpieza que cada módulo
# necesita al irse (en Delivery, soltar los repartos que quedaron asignados).
class AplicarBajasModulosJob < ApplicationJob
  queue_as :default

  def perform
    aplicadas = 0

    ActsAsTenant.without_tenant do
      # Sólo los que tienen algo programado: `features_baja` vacío es el caso normal.
      Club.where.not(features_baja: {}).find_each do |club|
        club.bajas_vencidas.each do |clave|
          ActsAsTenant.with_tenant(club) { Clubs::BajarModulo.call(club, clave) }
          aplicadas += 1
        rescue StandardError => e
          # Una organización que falla no puede frenar a las demás.
          Rails.logger.error("[MODULOS] no se pudo bajar #{clave} de club##{club.id}: #{e.class} #{e.message}")
        end
      end
    end

    Rails.logger.info("[MODULOS] bajas aplicadas: #{aplicadas}")
    aplicadas
  end
end
