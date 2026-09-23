module Dispensaciones
  # Cancelar una dispensación CONSERVANDO el registro: revierte stock, cuenta corriente y asientos,
  # y deja el evento en el historial.
  #
  # Vivía entero adentro de `DispensacionesController#cancelar_entrega`. Se extrajo cuando la
  # rendición del repartidor necesitó lo mismo —el paquete que vuelve se cancela igual— porque la
  # alternativa era escribir la reversa dos veces, y dos reversas de la misma cosa dejan de
  # coincidir a la primera corrección.
  class Cancelar
    Result = Struct.new(:ok, :dispensacion, :error, :a_favor_ars, :devuelto_ars, keyword_init: true) do
      def ok? = ok
    end

    def self.call(**kwargs) = new(**kwargs).call

    # `motivo` es uno de `Dispensacion::MOTIVOS_ANULACION` y decide CÓMO se deshace (ver el
    # modelo); `nota` es el texto libre de la persona. `descartar_producto` es para la devolución
    # de algo que no se puede volver a entregar (con `producto_defectuoso` va implícito).
    # `resolucion` (sólo con devolución o defectuoso): `devolver_plata` o `cambio` (defectuoso
    # nada más: el producto sano vuelve a la mesa y no hay nada que cambiar). `devolucion` dice
    # CÓMO vuelve la plata: `{ medio:, caja_turno_id: }` — el paciente pudo pagar por
    # transferencia y llevarse efectivo, o al revés. Sin `medio`, por donde pagó.
    #
    # `plata` (sólo `no_entregado`): qué se hace con lo que el paciente ya había pagado por el
    # paquete. `a_favor` (por defecto) o `devolver` — esto último sólo administración, y la plata
    # vuelve por `devolucion` igual que en una devolución.
    def initialize(dispensacion:, usuario:, motivo: 'error_carga', nota: nil, descartar_producto: false,
                   resolucion: nil, devolucion: {}, evento: true, plata: 'a_favor')
      @d          = dispensacion
      @usuario    = usuario
      @motivo     = motivo.to_s
      @nota       = nota.presence
      @descarta   = descartar_producto || @motivo == 'producto_defectuoso'
      @resolucion = resolucion.presence&.to_s
      @devolucion = (devolucion || {}).to_h.symbolize_keys
      @evento     = evento
      @plata      = plata.to_s
    end

    def call
      return err('La dispensación ya está cancelada') if @d.cancelada?
      return err('Motivo de anulación inválido') unless Dispensacion::MOTIVOS_ANULACION.include?(@motivo)
      if devolucion?
        @resolucion ||= 'devolver_plata'
        return err('Decí qué se hace: devolver la plata o cambiar el producto.') unless Dispensacion::RESOLUCIONES_ANULACION.include?(@resolucion)
        return err('El cambio es sólo para producto defectuoso: si vino sano, vuelve a la mesa.') if @resolucion == 'cambio' && @motivo != 'producto_defectuoso'
      else
        @resolucion = nil
      end
      return err('Decí qué se hace con lo que pagó: queda a favor o se le devuelve.') unless %w[a_favor devolver].include?(@plata)
      if @plata == 'devolver' && !(@usuario&.admin? || @usuario&.supervisor?)
        return err('Sólo administración puede devolver plata: queda a favor del paciente.')
      end

      ActiveRecord::Base.transaction do
        revertir_gramos
        revertir_cuenta_corriente
        CuentaCorrienteMovimiento.where(dispensacion_id: @d.id).update_all(dispensacion_id: nil)
        if devolucion?
          # La venta PASÓ: la plata entró. El ingreso y sus cobros quedan —son lo que cobró la
          # caja esa noche—. Si se devuelve, se escribe el egreso al lado; si se cambia el
          # producto, lo que pagó cubre lo que se lleva después (`Dispensacion#cambio?`).
          asentar_devolucion if @resolucion == 'devolver_plata'
        elsif no_entregado?
          dejar_a_favor_lo_cobrado
        else
          # Nunca pasó: el asiento se borra y los cobros (con sus comprobantes) se van con él.
          revertir_asientos
          @d.cobros.destroy_all
        end
        # El producto vuelve al stock —y a la mesa, si corresponde— o sale como merma.
        @d.revertir_stock!(vuelve: !@descarta, usuario: @usuario, nota: @nota)
        registrar_evento if @evento
        @d.update!(estado_envio: 'cancelada', historial_envio: @d.historial_envio,
                   motivo_anulacion: @motivo, nota_anulacion: @nota, resolucion_anulacion: @resolucion,
                   anulada_por: @usuario, anulada_at: Time.current)
      end
      Result.new(ok: true, dispensacion: @d, a_favor_ars: @a_favor.to_d, devuelto_ars: @devuelto.to_d)
    rescue => e
      err(e.message)
    end

    MEDIOS_DEVOLUCION = Devoluciones::CajaDeSalida::MEDIOS

    # LO QUE EL PACIENTE YA PAGÓ POR ESTA DISPENSA Y ENTRÓ DE VERDAD: los ingresos cobrados
    # (efectivo, transferencia) atados a ella. No cuenta el excedente («Aporte socio», que ya
    # quedó a favor el día que lo pagó) ni lo que se pagó con plata a favor o a cuenta corriente,
    # que la reversa de la cuenta corriente devuelve sola. Es lo que queda a favor si el paquete
    # no se entrega, y lo que la rendición le muestra a quien la recibe.
    def self.cobrado_de(dispensacion)
      dispensacion.movimientos_contables
                  .select { |m| m.es_ingreso? && m.pagado && m.categoria != 'aporte_socio' }
                  .sum(&:monto_ars).to_d
    end

    private

    def err(msg) = Result.new(ok: false, error: msg)
    def devolucion? = Dispensacion::MOTIVOS_CON_DEVOLUCION.include?(@motivo)
    def no_entregado? = @motivo == 'no_entregado'

    # EL PAQUETE QUE NO SE ENTREGÓ: LO QUE YA SE PAGÓ NO SE BORRA (Germán, 23-sep-2026).
    #
    # Antes se deshacía como un error de carga: se borraban el asiento y los cobros. Para un
    # paquete contra entrega está bien —no entró nada—, pero uno pagado por adelantado perdía la
    # plata: el ingreso desaparecía del libro, el cobro del arqueo (y la caja cerraba con un
    # sobrante que nadie explicaba) y el paciente no quedaba con nada a favor.
    #
    # Ahora, lo que ENTRÓ se queda donde está —el ingreso en el libro, el cobro en su caja— y el
    # paciente lo tiene A FAVOR: se le descuenta solo en la próxima dispensa. Es la opción segura
    # y no pide decidir nada, porque quien recibe la rendición del repartidor suele ser el
    # dispensador. Si administración prefiere devolverlo, lo hace acá mismo (`plata: 'devolver'`)
    # o después desde la cuenta corriente, con `CuentasCorrientes::DevolverSaldo`.
    #
    # Lo que NO entró se deshace como siempre: la deuda a cuenta corriente y lo pagado con plata
    # a favor vuelven con `revertir_cuenta_corriente`, y su asiento pendiente se borra.
    def dejar_a_favor_lo_cobrado
      @a_favor = self.class.cobrado_de(@d)
      @d.movimientos_contables.each do |m|
        next if m.es_ingreso? && m.pagado
        m.cerrado? ? contra_asentar(m) : m.destroy!
      end
      @d.cobros.where.not(medio: Cobro::MEDIOS_PAGADOS).destroy_all
      return if @a_favor <= 0

      cc       = @d.paciente.cuenta_corriente!
      anterior = cc.saldo_disponible.to_d
      nuevo    = anterior + @a_favor
      cc.update!(saldo_disponible: nuevo)
      cc.movimientos.create!(
        tipo: 'a_favor', unidad: 'ars', monto: @a_favor,
        saldo_anterior: anterior, saldo_nuevo: nuevo,
        descripcion: "Dispensación ##{@d.id} no entregada — lo que pagó queda a favor",
        dispensacion: @d, created_by: @usuario,
      )
      devolver_lo_cobrado if @plata == 'devolver'
    end

    def devolver_lo_cobrado
      caja = @devolucion.key?(:caja_turno_id) ? { caja_turno_id: @devolucion[:caja_turno_id] } : {}
      res = CuentasCorrientes::DevolverSaldo.call(
        paciente: @d.paciente, usuario: @usuario, monto: @a_favor,
        medio: @devolucion[:medio].presence || 'efectivo', caja: caja, dispensacion: @d,
      )
      raise ArgumentError, res.error unless res.ok?

      @devuelto = @a_favor
    end

    def registrar_evento
      @d.historial_envio = (@d.historial_envio || []) + [{
        estado: 'cancelado', at: Time.current.iso8601,
        por: @usuario&.nombre_completo, motivo: @motivo, nota: @nota,
        producto_descartado: (@descarta || nil),
      }.compact.stringify_keys]
    end

    # DEVOLVER LA PLATA. Por cada ingreso que se cobró de verdad (`pagado`), un egreso
    # «devolución a paciente» por el mismo monto y el mismo medio:
    #   · efectivo → sale HOY del cajón: pagado, con fecha de hoy y atado a la caja abierta de
    #     la sede (si no hay ninguna, se escribe igual y no entra a ningún arqueo, como cualquier
    #     pago en efectivo del admin). Si la caja de la venta sigue abierta, +venta −devolución
    #     da cero, que es lo que hay en el cajón.
    #   · transferencia / Mercado Pago → queda PENDIENTE hasta que se la transfieran de vuelta:
    #     se cierra con «Registrar pago».
    # Lo que no se cobró (cuenta corriente, no abona) no tiene plata que devolver: la cuenta
    # corriente ya se reacreditó arriba, y el asiento pendiente se borra si el período está
    # abierto.
    # UN SOLO EGRESO por todo lo cobrado, por el medio que se ELIGE — no necesariamente por el
    # que pagó: pagó por transferencia y se lleva efectivo, o al revés. Sin medio, por donde pagó.
    def asentar_devolucion
      pagados = @d.movimientos_contables.select { |m| m.es_ingreso? && m.pagado }
      @d.movimientos_contables.each { |m| m.destroy! if m.es_ingreso? && !m.pagado && !m.cerrado? }
      total = pagados.sum(&:monto_ars).to_d
      return if total <= 0

      medio = (@devolucion[:medio].presence || medio_por_donde_pago(pagados)).to_s
      raise ArgumentError, 'Elegí cómo se devuelve: efectivo, transferencia o Mercado Pago.' unless MEDIOS_DEVOLUCION.include?(medio)

      efectivo = medio == 'efectivo'
      caja     = efectivo ? caja_de_donde_sale!(total) : nil
      MovimientoContable.create!(
        club_id: @d.club_id, sede_id: @d.sede_id || pagados.first.sede_id, dispensacion: @d, paciente: @d.paciente,
        created_by: @usuario, tipo: 'egreso', categoria: 'devolucion_paciente',
        descripcion: "Devolución a #{@d.paciente&.nombre_completo} — dispensación ##{@d.id} anulada " \
                     "(#{Dispensacion::MOTIVOS_ANULACION_LABEL[@motivo].downcase})",
        monto_ars: total, fecha: Time.zone.today,
        medio_pago: medio, pagado: efectivo, fecha_pago: (efectivo ? Time.zone.today : nil),
        caja_turno_id: caja&.id, comprobante_tipo: 'sin_comprobante',
      )
    end

    def medio_por_donde_pago(pagados)
      medios = pagados.map(&:medio_pago).uniq
      medios.include?('efectivo') || medios.size != 1 ? 'efectivo' : medios.first
    end

    # De qué caja sale el efectivo: la regla vive en `Devoluciones::CajaDeSalida`.
    def caja_de_donde_sale!(monto)
      Devoluciones::CajaDeSalida.call(
        club_id: @d.club_id, sede_id: @d.sede_id, monto: monto,
        eligio_caja: @devolucion.key?(:caja_turno_id), caja_turno_id: @devolucion[:caja_turno_id],
      )
    end

    def fmt(n) = ActionController::Base.helpers.number_to_currency(n, unit: '$', separator: ',', delimiter: '.', precision: 0)

    # Un asiento en período ABIERTO se borra: la dispensa no pasó. Uno en período CERRADO no se
    # toca —ese mes ya se reportó y la plata entró de verdad ese día— y se escribe la devolución
    # con fecha de hoy, al lado. Antes el candado rechazaba la cancelación entera ("pertenece a un
    # período cerrado"), o sea que un paquete pagado por adelantado que falló y quedó en la calle
    # mientras se cerraba el mes no se podía cancelar ni volver a despachar sin reabrir el período.
    # Es la salida que el propio cierre promete: correcciones = contra-asiento.
    def revertir_asientos
      @d.movimientos_contables.each do |m|
        m.cerrado? ? contra_asentar(m) : m.destroy!
      end
    end

    def contra_asentar(m)
      return unless m.es_ingreso?

      MovimientoContable.create!(
        club: m.club, sede_id: m.sede_id, dispensacion: @d, paciente: m.paciente,
        created_by: @usuario, tipo: 'egreso', categoria: m.categoria,
        descripcion: "Devolución — cancelación de dispensación ##{@d.id} " \
                     "(asiento del #{m.fecha.strftime('%d/%m/%Y')}, período cerrado)",
        monto_ars: m.monto_ars, fecha: Time.zone.today,
        pagado: m.pagado, medio_pago: m.medio_pago, comprobante_tipo: 'sin_comprobante'
      )
    end

    def revertir_cuenta_corriente
      cc = @d.paciente&.cuenta_corriente
      return unless cc

      # Revertir el neto que esta dispensa dejó en la CC (solo pesos; los gramos van por
      # `revertir_gramos`). Dos efectos posibles, opuestos:
      #   - débito → deuda por el faltante (bajó el saldo) → al revertir SUMA.
      #   - pago   → crédito por el excedente pagado de más (subió el saldo) → al revertir RESTA.
      movs     = cc.movimientos.where(dispensacion: @d).where("unidad IS NULL OR unidad = 'ars'")
      debitos  = movs.where(tipo: 'debito').sum(:monto).abs
      creditos = movs.where(tipo: 'pago').sum(:monto)
      delta    = debitos - creditos
      return if delta.zero?

      anterior = cc.saldo_disponible
      nuevo    = anterior + delta
      cc.update!(saldo_disponible: nuevo)
      cc.movimientos.create!(
        tipo: 'ajuste', monto: delta, saldo_anterior: anterior, saldo_nuevo: nuevo,
        descripcion: "Reversa dispensación ##{@d.id}", created_by: @usuario
      )
    end

    def revertir_gramos
      cc = @d.paciente&.cuenta_corriente
      return unless cc

      # Por unidad='gramos' (registros nuevos) o por descripción como fallback (los anteriores a
      # la migración).
      total_g = cc.movimientos.where(dispensacion: @d, tipo: 'debito')
                  .where("unidad = 'gramos' OR descripcion ILIKE ?", '%(crédito gramos)%')
                  .sum(:monto).abs
      return if total_g <= 0

      anterior = cc.saldo_disponible_g.to_d
      nuevo    = anterior + total_g
      cc.update!(saldo_disponible_g: nuevo)
      cc.movimientos.create!(
        tipo: 'ajuste', monto: total_g, saldo_anterior: anterior, saldo_nuevo: nuevo,
        descripcion: "Reversa dispensación ##{@d.id} (gramos)", created_by: @usuario
      )
    end
  end
end
