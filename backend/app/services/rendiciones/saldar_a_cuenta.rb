module Rendiciones
  # El repartidor devuelve plata que se había quedado al rendir.
  #
  # Sin esto, lo que quedaba a su nombre se acumulaba para siempre: no había forma de decir "ya la
  # devolvió". Y "rendir en partes" —entregar hoy la mitad y mañana el resto— es exactamente esto:
  # se rinde todo, se recibe lo que trajo, y lo que faltó se salda después.
  #
  # La plata entra al cajón como cualquier otra que se pone a mano (`ingreso_caja`) y el saldo baja
  # con un movimiento espejo. NO es un ingreso del club: esa plata siempre fue suya, sólo estaba
  # en el bolsillo de otro.
  class SaldarACuenta
    Result = Struct.new(:ok, :monto, :error, keyword_init: true) do
      def ok? = ok
    end

    def self.call(**kwargs) = new(**kwargs).call

    def initialize(delivery:, club:, receptor:, monto:, notas: nil)
      @delivery = delivery
      @club     = club
      @receptor = receptor
      @monto    = monto.to_d
      @notas    = notas
    end

    # Lo que esta persona tiene del club y todavía no devolvió.
    def self.saldo_de(club, delivery)
      club.movimientos_contables
          .where(categoria: %w[a_cuenta_repartidor devolucion_a_cuenta], retirado_por_id: delivery.id)
          .sum('CASE WHEN categoria = %s THEN monto_ars ELSE -monto_ars END' %
               ActiveRecord::Base.connection.quote('a_cuenta_repartidor')).to_d
    end

    def call
      return err('El monto tiene que ser mayor a $0') if @monto <= 0

      saldo = self.class.saldo_de(@club, @delivery)
      return err('Esa persona no tiene nada a cuenta') if saldo <= 0
      if @monto > saldo
        return err("Sólo tiene $#{saldo.to_i} a cuenta: no se puede saldar más de lo que debe.")
      end

      ActiveRecord::Base.transaction do
        caja = caja_de_recepcion
        # Baja el saldo: el espejo de `a_cuenta_repartidor`, con la misma persona a nombre.
        MovimientoContable.create!(
          club: @club, sede_id: caja&.sede_id, created_by: @receptor, caja_turno: caja,
          tipo: 'ajuste', categoria: 'devolucion_a_cuenta', retirado_por: @delivery,
          descripcion: "Devolución de #{@delivery.nombre_completo}#{@notas.present? ? " — #{@notas}" : ''}",
          monto_ars: @monto, fecha: Time.zone.today,
          pagado: true, medio_pago: 'efectivo', comprobante_tipo: 'sin_comprobante'
        )
        # Y la plata entra al cajón de verdad, así el arqueo de la noche la espera.
        next if caja.nil?

        caja.movimientos_contables.create!(
          club: @club, sede_id: caja.sede_id, created_by: @receptor,
          tipo: 'ajuste', categoria: 'ingreso_caja',
          descripcion: "Ingreso a la caja — devolución de #{@delivery.nombre_completo}",
          monto_ars: @monto, fecha: Time.zone.today,
          pagado: true, medio_pago: 'efectivo', comprobante_tipo: 'sin_comprobante'
        )
      end
      Result.new(ok: true, monto: @monto)
    rescue ActiveRecord::RecordInvalid => e
      err(e.message)
    end

    private

    def err(msg) = Result.new(ok: false, error: msg)

    def caja_de_recepcion
      sedes = @receptor.sedes_ids_asignadas
      return CajaTurno.abierta_en_sede(club_id: @club.id, sede_id: sedes.first) if sedes.one?

      abiertas = CajaTurno.unscoped.where(club_id: @club.id, estado: 'abierta')
                          .de_mostradores.limit(2).to_a
      abiertas.one? ? abiertas.first : nil
    end
  end
end
