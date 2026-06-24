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
                    .where(club_id: @club.id).includes(dispensacion: :paciente)
      return Result.new(ok: true, total: 0, cantidad: 0) if cobros.empty?

      total = 0.to_d
      cant  = 0
      ActiveRecord::Base.transaction do
        cobros.each do |c|
          asentar!(c)
          c.update!(rendido: true, rendido_at: Time.current)
          total += c.monto_ars
          cant  += 1
        end
      end
      Result.new(ok: true, total: total.round(2), cantidad: cant)
    rescue => e
      Result.new(ok: false, error: e.message)
    end

    private

    def asentar!(cobro)
      d    = cobro.dispensacion
      quien = @delivery.first_name.presence || @delivery.email
      MovimientoContable.create!(
        club:             @club,
        sede_id:          d.sede_id,
        dispensacion:     d,
        paciente:         d.paciente,
        created_by:       @receptor,
        tipo:             'recupero_costo',
        categoria:        'dispensacion',
        descripcion:      "Recepción de caja (#{quien}) — Dispensación ##{d.id}",
        monto_ars:        cobro.monto_ars,
        fecha:            d.fecha_dispensacion,
        pagado:           true,
        medio_pago:       'efectivo',
        comprobante_tipo: 'sin_comprobante',
      )
    end
  end
end
