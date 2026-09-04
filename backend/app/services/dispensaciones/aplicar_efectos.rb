module Dispensaciones
  # Efectos FINANCIEROS de una dispensación: asiento contable + débito de cuenta corriente / gramos.
  # Extraído de DispensacionesController/DispensacionesFinancieras para que la creación, la edición y
  # la RESTAURACIÓN apliquen EXACTAMENTE la misma lógica. El stock se maneja aparte (callback en la
  # creación, explícito en la restauración). Parametrizado por `usuario` para poder correr fuera de
  # un request (la restauración no tiene current_user).
  class AplicarEfectos
    def self.financiero!(dispensacion:, usuario:)
      new(dispensacion, usuario).financiero!
    end

    def initialize(dispensacion, usuario)
      @disp    = dispensacion
      @usuario = usuario
    end

    # Aplica el medio de pago legacy (único): asiento + débito. Las dispensaciones con cobros
    # partidos NO pasan por acá (las arma aplicar_lineas_cobro! en el controller).
    def financiero!
      crear_movimiento_contable
      debitar_cuenta_corriente if @disp.a_credito?
      debitar_gramos           if @disp.medio_pago == 'credito_gramos'
    end

    def crear_movimiento_contable
      total = @disp.aporte_socio_ars.to_d
      return if total <= 0

      base_desc = "Dispensación #{@disp.cantidad}#{@disp.stock&.unidad} " \
        "#{@disp.stock&.forma_producto} — " \
        "#{@disp.paciente.nombre} #{@disp.paciente.apellido}"

      if @disp.a_credito?
        credito  = @disp.monto_credito_ars.to_d
        efectivo = total - credito
        asiento(credito,  "#{base_desc} (crédito)",  pagado: false, medio: @disp.medio_pago) if credito > 0
        asiento(efectivo, "#{base_desc} (efectivo)", pagado: true,  medio: 'efectivo')        if efectivo > 0
      else
        asiento(total, base_desc, pagado: true, medio: @disp.medio_pago || 'efectivo')
      end
    end

    def debitar_cuenta_corriente
      monto = @disp.monto_credito_ars.to_d
      return if monto <= 0

      cc = @disp.paciente.cuenta_corriente
      return if cc.nil?
      return if cc.movimientos.exists?(dispensacion: @disp, tipo: 'debito') # evita doble débito

      anterior = cc.saldo_disponible
      nuevo    = anterior - monto
      cc.update!(saldo_disponible: nuevo)
      cc.movimientos.create!(
        tipo: 'debito', unidad: 'ars', monto: -monto,
        saldo_anterior: anterior, saldo_nuevo: nuevo,
        descripcion:  "Dispensación: #{@disp.cantidad}#{@disp.stock&.unidad} #{@disp.stock&.forma_producto}",
        dispensacion: @disp, created_by: @usuario,
      )
    end

    def debitar_gramos
      gramos = @disp.cantidad.to_d
      return if gramos <= 0

      cc = @disp.paciente.cuenta_corriente
      return unless cc&.credito_gramos_activo?
      return if cc.movimientos.exists?(dispensacion: @disp, tipo: 'debito')

      anterior = cc.saldo_disponible_g.to_d
      nuevo    = anterior - gramos
      cc.update!(saldo_disponible_g: nuevo)
      cc.movimientos.create!(
        tipo: 'debito', unidad: 'gramos', monto: -gramos,
        saldo_anterior: anterior, saldo_nuevo: nuevo,
        descripcion:  "Dispensación #{gramos}g (crédito gramos)",
        dispensacion: @disp, created_by: @usuario,
      )
    end

    private

    def club
      @disp.paciente&.club || @usuario&.club
    end

    # IDEMPOTENTE, como el débito de cuenta corriente de arriba.
    #
    # Este camino asienta UNA vez por dispensa y medio de pago —la mixta lleva dos, uno de
    # crédito y uno de efectivo, y ahí termina—, así que un segundo asiento idéntico no es un
    # cobro más: es la misma operación aplicada dos veces. Y esa es exactamente la forma que
    # tomaría acá el bug que ya mordió en el stock, con el agravante de que un ingreso repetido
    # no se ve: no falta nada, sobra, y el resultado del mes queda inflado en silencio.
    #
    # No se pone un índice único en la base a propósito: `Dispensaciones::RegistrarCobro` asienta
    # por COBRO, y una dispensa puede tener dos cobros del mismo medio (pagó una parte hoy y otra
    # mañana). Una restricción por (dispensación, categoría, medio) rechazaría ese caso legítimo,
    # y romper un cobro parcial en producción es peor que el problema que evita.
    def asiento(monto, descripcion, pagado:, medio:)
      return if monto.to_d <= 0

      medio_pago = medio || 'efectivo'
      return if MovimientoContable.exists?(dispensacion_id: @disp.id, categoria: 'dispensacion',
                                           medio_pago: medio_pago, monto_ars: monto)

      MovimientoContable.create!(
        club:             club,
        sede_id:          @disp.sede_id,
        dispensacion:     @disp,
        created_by:       @usuario,
        tipo:             'recupero_costo',
        categoria:        'dispensacion',
        descripcion:      descripcion,
        monto_ars:        monto,
        fecha:            @disp.fecha_dispensacion,
        pagado:           pagado,
        medio_pago:       medio_pago,
        comprobante_tipo: 'sin_comprobante',
      )
    end
  end
end
