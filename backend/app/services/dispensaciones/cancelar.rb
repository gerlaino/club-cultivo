module Dispensaciones
  # Cancelar una dispensación CONSERVANDO el registro: revierte stock, cuenta corriente y asientos,
  # y deja el evento en el historial.
  #
  # Vivía entero adentro de `DispensacionesController#cancelar_entrega`. Se extrajo cuando la
  # rendición del repartidor necesitó lo mismo —el paquete que vuelve se cancela igual— porque la
  # alternativa era escribir la reversa dos veces, y dos reversas de la misma cosa dejan de
  # coincidir a la primera corrección.
  class Cancelar
    Result = Struct.new(:ok, :dispensacion, :error, keyword_init: true) do
      def ok? = ok
    end

    def self.call(**kwargs) = new(**kwargs).call

    # `motivo` es uno de `Dispensacion::MOTIVOS_ANULACION` y decide CÓMO se deshace (ver el
    # modelo); `nota` es el texto libre de la persona. `descartar_producto` es para la devolución
    # de algo que no se puede volver a entregar (con `producto_defectuoso` va implícito).
    def initialize(dispensacion:, usuario:, motivo: 'error_carga', nota: nil, descartar_producto: false, evento: true)
      @d        = dispensacion
      @usuario  = usuario
      @motivo   = motivo.to_s
      @nota     = nota.presence
      @descarta = descartar_producto || @motivo == 'producto_defectuoso'
      @evento   = evento
    end

    def call
      return err('La dispensación ya está cancelada') if @d.cancelada?
      return err('Motivo de anulación inválido') unless Dispensacion::MOTIVOS_ANULACION.include?(@motivo)

      ActiveRecord::Base.transaction do
        revertir_gramos
        revertir_cuenta_corriente
        CuentaCorrienteMovimiento.where(dispensacion_id: @d.id).update_all(dispensacion_id: nil)
        if devolucion?
          # La venta PASÓ: la plata entró y hay que devolverla. El ingreso y sus cobros quedan
          # —son lo que cobró la caja esa noche— y se escribe el egreso al lado.
          asentar_devolucion
        else
          # Nunca pasó: el asiento se borra y los cobros (con sus comprobantes) se van con él.
          revertir_asientos
          @d.cobros.destroy_all
        end
        # El producto vuelve al stock —y a la mesa, si corresponde— o sale como merma.
        @d.revertir_stock!(vuelve: !@descarta, usuario: @usuario, nota: @nota)
        registrar_evento if @evento
        @d.update!(estado_envio: 'cancelada', historial_envio: @d.historial_envio,
                   motivo_anulacion: @motivo, nota_anulacion: @nota,
                   anulada_por: @usuario, anulada_at: Time.current)
      end
      Result.new(ok: true, dispensacion: @d)
    rescue => e
      err(e.message)
    end

    private

    def err(msg) = Result.new(ok: false, error: msg)
    def devolucion? = Dispensacion::MOTIVOS_CON_DEVOLUCION.include?(@motivo)

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
    def asentar_devolucion
      @d.movimientos_contables.each do |m|
        next unless m.es_ingreso?

        if m.pagado
          MovimientoContable.create!(devolucion_attrs(m))
        elsif !m.cerrado?
          m.destroy!
        end
      end
    end

    def devolucion_attrs(m)
      efectivo = m.medio_pago == 'efectivo'
      caja_id  = efectivo ? CajaTurno.abierta_en_sede(club_id: m.club_id, sede_id: @d.sede_id || m.sede_id)&.id : nil
      {
        club: m.club, sede_id: @d.sede_id || m.sede_id, dispensacion: @d, paciente: m.paciente,
        created_by: @usuario, tipo: 'egreso', categoria: 'devolucion_paciente',
        descripcion: "Devolución a #{@d.paciente&.nombre_completo} — dispensación ##{@d.id} anulada " \
                     "(#{Dispensacion::MOTIVOS_ANULACION_LABEL[@motivo].downcase})",
        monto_ars: m.monto_ars, fecha: Time.zone.today,
        medio_pago: m.medio_pago, pagado: efectivo, fecha_pago: (efectivo ? Time.zone.today : nil),
        caja_turno_id: caja_id, comprobante_tipo: 'sin_comprobante',
      }
    end

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
