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
        # La caja del mostrador donde se recibe la plata. Se resuelve UNA vez: todos los cobros
        # de esta rendición entran juntos al mismo turno.
        caja = caja_de_recepcion
        cobros.each do |c|
          asentar!(c)
          # Recién ahora el efectivo está en el cajón: acá es donde se engancha a la caja, no
          # cuando el repartidor lo cobró en la puerta.
          c.update!(rendido: true, rendido_at: Time.current, caja_turno: caja)
          total += c.monto_ars
          cant  += 1
        end
      end
      Result.new(ok: true, total: total.round(2), cantidad: cant)
    rescue => e
      Result.new(ok: false, error: e.message)
    end

    private

    # `unscoped` y no `without_tenant`: este servicio corre desde el panel del admin, y
    # `without_tenant` toca estado global y se filtra entre ejemplos.
    def caja_de_recepcion
      CajaTurno.unscoped.where(club_id: @club.id, punto_type: 'Sede', estado: 'abierta')
               .order(abierta_at: :desc).first
    end

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
