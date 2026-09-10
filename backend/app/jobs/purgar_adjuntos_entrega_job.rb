# Borra las IMÁGENES de una entrega pasados `Dispensacion::RETENCION_IMAGENES_ENTREGA` días.
#
# QUÉ SE BORRA Y QUÉ NO. Sólo lo que produjo el reparto: la firma del receptor y la foto de la
# entrega. NO se toca:
#   · la dispensación, que es registro contable;
#   · el comprobante de PAGO (`Cobro#comprobante`), que es la foto de una transferencia que trajo
#     el paciente. Nadie la puede volver a generar, y además ese adjunto lo usan también el
#     mostrador y las reservas: un barrido ciego se llevaría puesto el respaldo de un asiento.
#   · `comprobante_tipo`/`comprobante_numero`, que son TEXTO (factura A/B, recibo), no imágenes.
#
# La regla de fondo: SE BORRA LO QUE NO SE PUEDE REGENERAR Y YA NO HACE FALTA. Lo que el club
# EMITE (un recibo) no se guarda nunca — se calcula cuando se pide.
#
# Y EL HUECO TIENE QUE HABLAR: si la imagen desaparece sin rastro, una entrega vieja se ve
# IDÉNTICA a una donde nadie firmó, y eso hace dudar del registro entero. Por eso queda un evento
# en `historial_envio` —la bitácora del envío, que ya existe— y la ficha dice "firmado el 9-sep,
# imagen borrada por antigüedad".
class PurgarAdjuntosEntregaJob < ApplicationJob
  queue_as :default

  def perform
    corte = Dispensacion::RETENCION_IMAGENES_ENTREGA.ago
    purgadas = 0

    # `with_deleted`: una dispensa dada de baja tampoco necesita conservar la imagen — y sin esto
    # el default_scope de paranoia las dejaba afuera para siempre.
    Dispensacion.with_deleted
                .where('COALESCE(entregado_at, fallido_at, created_at) < ?', corte)
                .where(id: con_imagenes_ids)
                .find_each(batch_size: 200) do |d|
      purgadas += 1 if purgar(d)
    end

    Rails.logger.info("[PurgarAdjuntosEntregaJob] #{purgadas} entrega(s) sin imágenes, corte #{corte.to_date}")
    purgadas
  end

  private

  # Las dos puertas por las que una entrega puede tener imagen. Se junta ANTES para no recorrer
  # la tabla entera preguntando por un adjunto de a una fila.
  def con_imagenes_ids
    con_firma = Dispensacion.with_deleted.where.not(firma_entrega_data: nil).select(:id)
    con_foto  = ActiveStorage::Attachment.where(record_type: 'Dispensacion', name: 'comprobante_entrega')
                                         .select(:record_id)
    Dispensacion.with_deleted.where(id: con_firma).or(Dispensacion.with_deleted.where(id: con_foto)).select(:id)
  end

  def purgar(dispensacion)
    tenia_firma = dispensacion.firma_entrega_data.present?
    tenia_foto  = dispensacion.comprobante_entrega.attached?
    return false unless tenia_firma || tenia_foto

    dispensacion.comprobante_entrega.purge if tenia_foto

    evento = {
      'evento' => 'imagenes_purgadas',
      'fecha'  => Time.current.iso8601,
      'motivo' => "retención de #{Dispensacion::RETENCION_IMAGENES_ENTREGA.inspect}",
      'firma'  => tenia_firma,
      'foto'   => tenia_foto,
    }
    # `update_columns`: sin validaciones (una fila vieja no puede trabar la limpieza) y sin tocar
    # `updated_at` — borrar una imagen por antigüedad no es "modificaron la dispensa hoy".
    dispensacion.update_columns(
      firma_entrega_data: nil,
      historial_envio:    (dispensacion.historial_envio || []) + [evento],
    )
    true
  rescue StandardError => e
    Rails.logger.error("[PurgarAdjuntosEntregaJob] ##{dispensacion.id}: #{e.message}")
    false
  end
end
