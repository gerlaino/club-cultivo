module Webhooks
  # POST /webhooks/mercado_pago — los avisos de Mercado Pago sobre las suscripciones.
  #
  # Sin usuario y sin tenant (como `LecturasController`). La autorización es la FIRMA
  # (`x-signature`, `MercadoPago.firma_valida?`); sin firma válida no se procesa nada. Y aun firmado,
  # el aviso sólo dice qué mirar: `Pagos::Suscripciones::ProcesarAviso` le vuelve a pedir el recurso a
  # MP. Responde 200 rápido; si MP no contesta, 502 para que reintente.
  class MercadoPagoController < ActionController::API
    around_action { |_, bloque| ActsAsTenant.without_tenant { bloque.call } }

    def create
      tipo = params[:type].presence || params[:topic].presence
      id   = params.dig(:data, :id).presence || params['data.id'].presence || params[:id].presence
      return head :ok if tipo.blank? || id.blank? # avisos de otra cosa: se acusan y se ignoran

      firma_ok = Pagos::MercadoPago.firma_valida?(firma: request.headers['x-signature'],
                                                  request_id: request.headers['x-request-id'], data_id: id)
      return head :unauthorized unless firma_ok

      Pagos::Suscripciones::ProcesarAviso.new(tipo: tipo, id: id).call
      head :ok
    rescue Pagos::MercadoPago::Error => e
      Rails.logger.warn("[mercado pago] aviso #{tipo} #{id}: #{e.message}")
      head :bad_gateway
    end
  end
end
