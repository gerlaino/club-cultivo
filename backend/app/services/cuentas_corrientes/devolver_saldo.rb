module CuentasCorrientes
  # DEVOLVERLE AL PACIENTE PLATA QUE TIENE A FAVOR (Germán, 23-sep-2026).
  #
  # Lo que un paciente tiene a favor es plata que ya entró —pagó de más, o pagó un paquete que no
  # se le pudo entregar— y por defecto se descuenta sola en la próxima dispensa. A veces no hay
  # próxima, o el paciente la pide: administración (admin o supervisor) se la devuelve.
  #
  # Dos efectos, en una transacción:
  #   · la cuenta corriente BAJA por el monto (movimiento `devolucion`): ya no la tiene a favor;
  #   · un EGRESO «devolución a paciente», el mismo asiento que escribe la anulación por
  #     devolución. En efectivo sale HOY de una caja (o de ninguna: administración, de su
  #     bolsillo) y queda pagado; por transferencia o Mercado Pago queda PENDIENTE hasta que se
  #     la transfieran, y se cierra con «Registrar pago».
  #
  # Sólo se devuelve lo que está a favor: nunca deja la cuenta en negativo.
  class DevolverSaldo
    Result = Struct.new(:ok, :movimiento, :error, keyword_init: true) do
      def ok? = ok
    end

    def self.call(**kwargs) = new(**kwargs).call

    # `caja`: `{ caja_turno_id: }` si la persona eligió caja (nil = ninguna); sin la clave, la
    # abierta de la sede. `dispensacion`: la dispensa de la que viene la plata, si hay una.
    def initialize(paciente:, usuario:, monto:, medio:, caja: {}, dispensacion: nil, nota: nil)
      @paciente = paciente
      @usuario  = usuario
      @monto    = monto.to_d.round(2)
      @medio    = medio.to_s
      @caja     = (caja || {}).to_h.symbolize_keys
      @disp     = dispensacion
      @nota     = nota.presence
    end

    def call
      return err('Sólo administración puede devolver plata.') unless @usuario&.admin? || @usuario&.supervisor?
      return err('El monto tiene que ser mayor a $0.') unless @monto.positive?
      return err('Elegí cómo se devuelve: efectivo, transferencia o Mercado Pago.') unless Devoluciones::CajaDeSalida::MEDIOS.include?(@medio)

      mov = nil
      ActiveRecord::Base.transaction do
        cc = @paciente.cuenta_corriente!
        cc.lock!
        a_favor = cc.saldo_a_favor
        if @monto > a_favor + 0.001
          raise ArgumentError, "#{@paciente.nombre_completo} tiene #{fmt(a_favor)} a favor: no se le pueden devolver #{fmt(@monto)}."
        end

        efectivo = @medio == 'efectivo'
        caja     = efectivo ? caja_de_salida : nil
        anterior = cc.saldo_disponible.to_d
        nuevo    = anterior - @monto
        cc.update!(saldo_disponible: nuevo)
        mov = cc.movimientos.create!(
          tipo: 'devolucion', unidad: 'ars', monto: -@monto,
          saldo_anterior: anterior, saldo_nuevo: nuevo,
          descripcion: descripcion, dispensacion: @disp, created_by: @usuario,
        )
        MovimientoContable.create!(
          club_id: @paciente.club_id, sede_id: sede_id, dispensacion: @disp, paciente: @paciente,
          created_by: @usuario, tipo: 'egreso', categoria: 'devolucion_paciente',
          descripcion: "Devolución a #{@paciente.nombre_completo} — #{origen}",
          monto_ars: @monto, fecha: Time.zone.today,
          medio_pago: @medio, pagado: efectivo, fecha_pago: (efectivo ? Time.zone.today : nil),
          caja_turno_id: caja&.id, comprobante_tipo: 'sin_comprobante',
        )
      end
      Result.new(ok: true, movimiento: mov)
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      err(e.message)
    end

    private

    def err(msg) = Result.new(ok: false, error: msg)

    def caja_de_salida
      Devoluciones::CajaDeSalida.call(
        club_id: @paciente.club_id, sede_id: sede_id, monto: @monto,
        eligio_caja: @caja.key?(:caja_turno_id), caja_turno_id: @caja[:caja_turno_id],
      )
    end

    # El egreso necesita una sede: la de la dispensa, o la de la caja elegida, o la primera activa.
    def sede_id
      @sede_id ||= @disp&.sede_id ||
                   CajaTurno.unscoped.find_by(id: @caja[:caja_turno_id])&.sede_id ||
                   @paciente.club.sedes.activas.first&.id
    end

    def origen
      base = @disp ? "dispensación ##{@disp.id} no entregada" : 'plata que tenía a favor'
      @nota ? "#{base} (#{@nota})" : base
    end

    def descripcion
      medio = { 'efectivo' => 'en efectivo', 'transferencia' => 'por transferencia', 'mercado_pago' => 'por Mercado Pago' }[@medio]
      "Se le devolvió #{medio}#{@disp ? " — dispensación ##{@disp.id}" : ''}"
    end

    def fmt(n) = Devoluciones::CajaDeSalida.fmt(n)
  end
end
