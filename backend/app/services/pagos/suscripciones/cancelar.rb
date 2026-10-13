module Pagos
  module Suscripciones
    # Cancela la suscripción en Mercado Pago y acá. Lo ya cobrado no se toca: el plan sigue hasta
    # la fecha que pagó (`plan_activo_hasta`).
    class Cancelar
      def initialize(suscripcion, cliente: MercadoPago.new)
        @s = suscripcion
        @cliente = cliente
      end

      def call
        @cliente.actualizar_preapproval(@s.mp_preapproval_id, status: 'cancelled') if @s.mp_preapproval_id.present?
        @s.update!(estado: 'cancelada')
        @s
      end
    end
  end
end
