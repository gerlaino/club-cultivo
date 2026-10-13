module Dispensaciones
  # LOS NÚMEROS DE ARRIBA DEL HISTORIAL DE DISPENSACIONES, en una sola cuenta (13-oct-2026).
  #
  # Germán vio «A cuenta corriente $521.500» al lado del chip «Cta. cte.: 6 ($558.000)»: la pantalla
  # sacaba la tarjeta de lo que quedó debiendo cada paciente y el chip del PRECIO ENTERO de las
  # dispensas etiquetadas «cuenta corriente» —aunque se hubieran pagado en parte—. Mismo nombre,
  # dos números. Desde los cobros por línea una dispensa se paga con varios medios, y la etiqueta
  # `medio_pago` ya no reparte la plata. La plata se cuenta por COBRO, cada peso en su medio:
  #
  #   cobrado            efectivo + transferencia: lo que entró de verdad.
  #   saldo a favor      lo que el paciente ya había dejado pagado y consumió (sin ingreso hoy).
  #   cuenta corriente   lo que quedó debiendo en estas dispensas.
  #   pendiente          contra entrega todavía sin cobrar (el resto sin cobro).
  #
  # Y aparte, la DEUDA TOTAL de los pacientes hoy, que no depende del período: la misma cuenta que
  # el panel de inicio (`Contabilidad::Posicion#por_cobrar_ars`).
  #
  # Qué dispensas suman (lo que hacía la pantalla): las vigentes, y las anuladas con CAMBIO, cuya
  # plata quedó (la dispensa de cambio cobra $0). Una anulada sin cambio no suma: se devolvió.
  class Resumen
    MEDIOS = Cobro::MEDIOS

    # `con_deuda_total`: la deuda de TODOS los pacientes es de administración; el dispensador ve
    # lo que pasó en sus dispensas, no la cartera entera de la organización.
    def initialize(dispensaciones, club:, con_deuda_total: false)
      @todas = dispensaciones.to_a
      @club  = club
      @con_deuda_total = con_deuda_total
    end

    def call
      vigentes = @todas.reject(&:cancelada?)
      cobradas = @todas.select { |d| !d.cancelada? || d.resolucion_anulacion == 'cambio' }
      cobros   = Cobro.where(dispensacion_id: cobradas.map(&:id)).group(:dispensacion_id, :medio).sum(:monto_ars)

      por_medio = (MEDIOS + ['sin_detalle']).to_h { |m| [m, { monto: 0.to_d, dispensas: 0 }] }
      pendiente = 0.to_d
      cobradas.each do |d|
        next if d.cambio? # lo pagó la anulada que reemplaza, que ya está sumada

        propios = MEDIOS.to_h { |m| [m, cobros[[d.id, m]].to_d] }
        # La misma regla que `Dispensacion#usa_cobros?` (contra entrega, o ya tiene cobros), sin
        # una consulta por dispensa: una de contra entrega sin cobrar todavía NO es vieja.
        viejo = !d.cobrar_en_entrega? && propios.values.sum.zero? && d.aporte_socio_ars.to_d.positive?
        propios = legacy(d) if viejo
        propios.each do |m, monto|
          next unless monto.positive?

          por_medio[m][:monto] += monto
          por_medio[m][:dispensas] += 1
        end
        # Lo que falta cobrar sólo se sabe con cobros por línea; en una vieja no es «pendiente».
        pendiente += [d.aporte_socio_ars.to_d - propios.values.sum, 0].max unless viejo
      end

      resumen = {
        dispensas:            vigentes.size,
        gramos:               vigentes.sum { |d| d.cantidad.to_d }.to_f,
        cobrado_ars:          (por_medio['efectivo'][:monto] + por_medio['transferencia'][:monto] +
                               por_medio['sin_detalle'][:monto]).to_f,
        saldo_a_favor_ars:    por_medio['saldo_a_favor'][:monto].to_f,
        cuenta_corriente_ars: por_medio['cuenta_corriente'][:monto].to_f,
        pendiente_ars:        pendiente.to_f,
        por_medio:            por_medio.filter_map do |m, v|
          { medio: m, monto_ars: v[:monto].to_f, dispensas: v[:dispensas] } if v[:monto].positive?
        end,
        regalos:              vigentes.count { |d| d.medio_pago == 'regalo' },
      }
      return resumen unless @con_deuda_total

      posicion = Contabilidad::Posicion.new(club: @club)
      resumen.merge(deuda_total_ars: posicion.por_cobrar_ars, deudores: posicion.deudas.count)
    end

    private

    # Dispensas de antes de los cobros por línea: la deuda es `monto_credito_ars` y el resto va al
    # medio que dice la dispensa (si es uno de plata). Sin esto, un período viejo daba todo cero.
    # Lo que no se sabe cómo se pagó («mixto» viejo) va a `sin_detalle`, no se inventa.
    def legacy(d)
      montos = (MEDIOS + ['sin_detalle']).to_h { |m| [m, 0.to_d] }
      credito = d.monto_credito_ars.to_d
      montos['cuenta_corriente'] = credito
      resto = d.aporte_socio_ars.to_d - credito
      if resto.positive?
        destino = %w[efectivo transferencia].include?(d.medio_pago) ? d.medio_pago : 'sin_detalle'
        montos[destino] += resto
      end
      montos
    end
  end
end
