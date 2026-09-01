module Dispensaciones
  # Recepción de caja: el admin recibe el efectivo que el delivery cobró en las
  # entregas. Recién en este momento se asienta el ingreso en contabilidad (el efectivo
  # estaba "en tránsito") y se marca cada cobro como rendido.
  class RecibirCajaDelivery
    Result = Struct.new(:ok, :total, :cantidad, :error, keyword_init: true) do
      def ok? = ok
    end

    def self.call(**kwargs) = new(**kwargs).call

    def initialize(delivery:, club:, receptor:)
      @delivery = delivery
      @club     = club
      @receptor = receptor
    end

    def call
      cobros = Cobro.efectivo_en_transito.del_delivery(@delivery.id)
                    .where(club_id: @club.id, rendicion_caja_id: nil)
                    .includes(dispensacion: :paciente)
      return Result.new(ok: true, total: 0, cantidad: 0) if cobros.empty?

      # Es la MISMA entrega que hace el repartidor desde su pantalla, sólo que la arranca el que
      # recibe (el repartidor se fue sin rendir, o es una organización que no usa ese botón). Se
      # crea la rendición y se recibe en un paso, para que todo pase por un solo modelo del hecho
      # y no queden dos formas distintas de que la plata entre al cajón.
      rendicion = RendicionCaja.create!(
        club: @club, delivery: @delivery, receptor: @receptor, estado: 'pendiente',
        monto_declarado_ars: cobros.sum { |c| c.monto_ars.to_d },
        cobros_count: cobros.size, rendida_at: Time.current
      )
      Cobro.where(id: cobros.map(&:id)).update_all(rendicion_caja_id: rendicion.id)

      res = Rendiciones::Recibir.call(rendicion: rendicion, receptor: @receptor)
      return Result.new(ok: false, error: res.error) unless res.ok?

      Result.new(ok: true, total: res.rendicion.monto_recibido_ars.to_d.round(2),
                 cantidad: rendicion.cobros_count)
    rescue => e
      Result.new(ok: false, error: e.message)
    end

    private

    # El asiento del ingreso y la resolución de la caja viven en `Rendiciones::Recibir`: es la
    # misma entrega, la arranque quien la arranque. Tenerlo escrito acá también era la receta
    # para que las dos formas de recibir dejaran de coincidir.
  end
end
