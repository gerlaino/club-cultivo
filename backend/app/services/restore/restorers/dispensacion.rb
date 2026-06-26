module Restore
  module Restorers
    # Restaura una dispensación re-aplicando sus efectos (descuenta stock, asiento contable,
    # débito de cuenta corriente/gramos) con la MISMA lógica que la creación (vía
    # Dispensaciones::AplicarEfectos). Valida contra el estado ACTUAL y bloquea con motivos:
    # si el crédito ya se consumió o el stock no alcanza, no restaura (política del proyecto).
    #
    # v1: cubre el medio de pago legacy (efectivo/transferencia/cuenta_corriente/no_abona/
    # credito_gramos). Las dispensaciones con cobros partidos se bloquean con motivo (su
    # restauración —reconstruir el desglose de cobros— es un paso aparte).
    class Dispensacion < Restore::Base
      def conflicts
        d  = record
        cs = []

        cs << conflict('paciente_inexistente', 'El socio de esta dispensación ya no existe.') if ::Paciente.where(id: d.paciente_id).none?

        stock = ::Stock.find_by(id: d.stock_id)
        if stock.nil?
          cs << conflict('stock_inexistente', 'El stock dispensado ya no existe.')
        elsif stock.cantidad_disponible_real.to_d < d.cantidad.to_d
          disp = stock.cantidad_disponible_real.to_d
          cs << conflict('stock_insuficiente',
            "Stock insuficiente: hay #{disp.round(2)}#{stock.unidad || 'g'} disponibles y la dispensa requiere #{d.cantidad}#{stock.unidad || 'g'}.")
        end

        if cobros?
          cs << conflict('cobros_no_soportado',
            'Esta dispensación tiene cobros partidos / contra-entrega. Su restauración todavía no está soportada.')
          return cs # sin sentido validar crédito en este caso
        end

        cs.concat(conflictos_credito(d))
        cs << conflict('periodo_cerrado', 'La fecha cae en un período contable ya cerrado.') if periodo_cerrado?(d)
        cs
      end

      private

      def cobros?
        record.cobrar_en_entrega? || record.cobros.with_deleted.exists?
      end

      def conflictos_credito(d)
        cc = d.paciente&.cuenta_corriente

        if d.a_credito?
          monto = d.monto_credito_ars.to_d
          return [] if monto <= 0
          return [conflict('sin_cuenta_corriente', 'El socio no tiene cuenta corriente configurada.')] if cc.nil?

          disponible = cc.saldo_disponible.to_d + cc.limite_credito.to_d
          if disponible < monto
            return [conflict('credito_insuficiente',
              "Crédito insuficiente: necesita $#{monto.to_f} y el socio dispone de $#{disponible.to_f}.")]
          end
        elsif d.medio_pago == 'credito_gramos'
          saldo_g = cc&.saldo_disponible_g.to_d
          if !cc&.credito_gramos_activo? || saldo_g < d.cantidad.to_d
            return [conflict('gramos_insuficiente',
              "Saldo en gramos insuficiente: hay #{saldo_g.to_f}g y la dispensa requiere #{d.cantidad}g.")]
          end
        end

        []
      end

      def periodo_cerrado?(d)
        cierre = d.paciente&.club&.contabilidad_cerrada_hasta
        cierre.present? && d.fecha_dispensacion.present? && d.fecha_dispensacion <= cierre
      end

      def apply!
        d = record
        d.send(:decrementar_stock)
        Dispensaciones::AplicarEfectos.financiero!(dispensacion: d, usuario: usuario || d.deleted_by || d.user)
      end

      # apply! crea asientos/movimientos frescos; no des-borramos los viejos (quedarían duplicados).
      def recursive_restore? = false
    end
  end
end
