module Dispensaciones
  # Fuente de verdad para registrar UNA línea de cobro de una dispensación.
  # La usan los tres puntos de entrada: dispensar, entrega del delivery, y el
  # recupero desde Contabilidad. Valida los bloqueos del flujo y arma la
  # contabilidad (asiento + débito de cuenta corriente) en una sola transacción.
  #
  #   efectivo / transferencia → ingreso real (pagado: true). No toca cuenta corriente.
  #   cuenta_corriente         → deuda (pagado: false). Debita el cupo del socio.
  #
  # Reglas (bloquea cuando corresponde):
  #   - No se puede cobrar más que el saldo pendiente de la dispensa.
  #   - cuenta_corriente exige cuenta corriente activa (limite_credito > 0).
  #   - cuenta_corriente exige cupo suficiente (saldo_disponible + limite >= monto).
  class RegistrarCobro
    Result = Struct.new(:ok, :cobro, :error, keyword_init: true) do
      def ok? = ok
    end

    def self.call(**kwargs) = new(**kwargs).call

    def initialize(dispensacion:, club:, usuario:, medio:, monto:, contexto: 'creacion', comprobante: nil, notas: nil)
      @dispensacion = dispensacion
      @club         = club
      @usuario      = usuario
      @medio        = medio.to_s
      @monto        = monto.to_d
      @contexto     = contexto.to_s
      @comprobante  = comprobante
      @notas        = notas
    end

    def call
      if (msg = validar)
        return Result.new(ok: false, error: msg)
      end

      cobro = nil
      ActiveRecord::Base.transaction do
        cobro = @dispensacion.cobros.create!(
          club:       @club,
          created_by: @usuario,
          medio:      @medio,
          monto_ars:  @monto,
          contexto:   @contexto,
          notas:      @notas,
          # Efectivo de entrega: queda en tránsito (se asienta al recibir la caja).
          rendido:    !diferido_a_rendicion?,
          # Engancha el cobro a la caja abierta del mostrador, igual que una venta del bar. Es lo
          # que permite arquear sumando lo cobrado en el turno en vez de adivinar por ventana de
          # tiempo, que se rompe apenas alguien abre tarde o cierra al otro día. Si no hay caja
          # abierta el cobro se registra igual: la caja es una herramienta de control, no un
          # requisito para entregar.
          caja_turno: caja_abierta,
        )
        cobro.comprobante.attach(@comprobante) if @comprobante.present?
        # El asiento del efectivo de entrega se difiere hasta la recepción de caja.
        asiento_contable(cobro) unless diferido_a_rendicion?
        debitar_cuenta_corriente(cobro) if @medio == 'cuenta_corriente'
      end
      Result.new(ok: true, cobro: cobro)
    rescue => e
      Result.new(ok: false, error: e.message)
    end

    private

    def validar
      return 'El monto debe ser mayor a $0.'             unless @monto > 0
      return 'Medio de pago inválido.'                   unless Cobro::MEDIOS.include?(@medio)

      saldo = @dispensacion.monto_sin_cobrar
      return "El cobro ($#{@monto.to_f}) supera el saldo pendiente ($#{saldo.to_f}) de la dispensa." if @monto > saldo + 0.001

      if @medio == 'cuenta_corriente'
        cc = cuenta_corriente
        return 'El socio no tiene cuenta corriente habilitada para dejar saldo en cuenta.' unless cc&.tiene_credito?
        return 'Crédito insuficiente: el monto a dejar en cuenta supera el cupo disponible del socio.' unless cc.puede_dispensar?(@monto)
      end
      nil
    end

    # La caja abierta del mostrador donde se está cobrando. Sin sede no hay mostrador.
    def caja_abierta
      sede = @dispensacion.sede || @dispensacion.stock&.sede
      return nil if sede.nil?

      # `unscoped` + club_id explícito, y NO `without_tenant`: este servicio también corre desde
      # la entrega del repartidor y desde Contabilidad, donde no hay tenant fijado, así que con
      # `require_tenant` la query tal cual revienta. Pero `without_tenant` toca estado GLOBAL —lo
      # pone en nil y lo restaura— y eso se filtra entre ejemplos: la spec siguiente hereda el
      # tenant cambiado y falla en su propio setup, lejos de acá. `unscoped` es local a la query.
      CajaTurno.unscoped.where(club_id: @club.id, punto_type: 'Sede', punto_id: sede.id,
                               estado: 'abierta').first
    end

    def cuenta_corriente
      @cuenta_corriente ||= @dispensacion.paciente.cuenta_corriente
    end

    # Efectivo cobrado por el DELIVERY en la entrega: su asiento se difiere hasta la
    # recepción de caja (caja en tránsito). Si entrega un admin/supervisor, la plata
    # entra directo a la caja del club → se asienta en el acto (no se difiere).
    def diferido_a_rendicion?
      @medio == 'efectivo' && @contexto == 'entrega' && @usuario&.role == 'delivery'
    end

    def asiento_contable(cobro)
      base = "Dispensación #{@dispensacion.cantidad}#{@dispensacion.stock&.unidad} " \
             "#{@dispensacion.stock&.forma_producto} — " \
             "#{@dispensacion.paciente.nombre} #{@dispensacion.paciente.apellido}"
      sufijo = cobro.a_credito? ? ' (cuenta corriente)' : " (#{cobro.medio})"

      MovimientoContable.create!(
        club:             @club,
        sede_id:          @dispensacion.sede_id,
        dispensacion:     @dispensacion,
        paciente:         @dispensacion.paciente,
        created_by:       @usuario,
        tipo:             'recupero_costo',
        categoria:        'dispensacion',
        descripcion:      base + sufijo,
        monto_ars:        @monto,
        fecha:            @dispensacion.fecha_dispensacion,
        pagado:           cobro.pagado,
        medio_pago:       @medio,
        comprobante_tipo: 'sin_comprobante',
      )
    end

    def debitar_cuenta_corriente(cobro)
      cc       = cuenta_corriente
      anterior = cc.saldo_disponible
      nuevo    = anterior - @monto
      cc.update!(saldo_disponible: nuevo)
      cc.movimientos.create!(
        tipo:           'debito',
        unidad:         'ars',
        monto:          -@monto,
        saldo_anterior: anterior,
        saldo_nuevo:    nuevo,
        descripcion:    "Dispensación: #{@dispensacion.cantidad}#{@dispensacion.stock&.unidad} #{@dispensacion.stock&.forma_producto} (a cuenta)",
        dispensacion:   @dispensacion,
        created_by:     @usuario,
      )
    end
  end
end
