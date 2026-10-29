module Seguridad
  # El link a un archivo con datos de una persona VENCE (29-oct-2026, seguridad tanda 2, FILES-01).
  #
  # `url_for(adjunto)` / `rails_blob_path` arman `/rails/active_storage/blobs/redirect/<id firmado>/…`,
  # que no pide sesión y, sin `expires_in`, vale PARA SIEMPRE: un comprobante de transferencia, la
  # foto del DNI o la constancia del REPROCANN quedaban abiertos a quien tuviera el link (reenviado
  # por WhatsApp, el historial de una compu compartida). Con esto el link vale una hora; la pantalla
  # lo vuelve a pedir cada vez que abre la ficha, así que nadie lo ve vencer trabajando.
  #
  # Sólo para lo privado. Las fotos de genéticas, lotes y el logo NO pasan por acá: se muestran en
  # páginas públicas y el service worker las guarda por URL (un link que cambia en cada pedido no
  # se guardaría nunca).
  module ArchivoPrivado
    VIGENCIA = 1.hour

    def self.ruta(adjunto)
      return nil unless adjunto&.attached?

      helpers.rails_blob_path(adjunto, only_path: true, expires_in: VIGENCIA)
    end

    def self.url(adjunto)
      return nil unless adjunto&.attached?

      helpers.rails_blob_url(adjunto, expires_in: VIGENCIA)
    end

    def self.helpers = Rails.application.routes.url_helpers
  end
end
