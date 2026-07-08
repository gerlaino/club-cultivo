module Restore
  module Restorers
    # Restaura una venta del bar re-aplicando sus efectos: vuelve a descontar el stock de los
    # productos y re-crea el ingreso contable. Valida contra el estado ACTUAL y bloquea con
    # motivos (política del proyecto): si algún producto ya no existe o no hay stock, no restaura.
    class BarVenta < Restore::Base
      def conflicts
        cs = []
        record.items.with_deleted.each do |it|
          prod = ::BarProducto.with_deleted.find_by(id: it.bar_producto_id)
          if prod.nil?
            cs << conflict('producto_inexistente', "El producto \"#{it.nombre}\" ya no existe.")
          elsif prod.stock.to_d < it.cantidad.to_d
            cs << conflict('stock_insuficiente',
              "Sin stock de \"#{it.nombre}\": hay #{prod.stock.to_f} y la venta requiere #{it.cantidad.to_f}.")
          end
        end
        cs << conflict('periodo_cerrado', 'La fecha cae en un período contable ya cerrado.') if periodo_cerrado?
        cs
      end

      private

      def apply!
        v = record
        # Las líneas son estructura: se restauran con la venta para poder descontar stock.
        v.items.with_deleted.where.not(deleted_at: nil).each(&:restore)
        v.items.each { |it| it.bar_producto&.update!(stock: it.bar_producto.stock.to_d - it.cantidad.to_d) }
        v.crear_ingreso!
      end

      def periodo_cerrado?
        cierre = record.club&.contabilidad_cerrada_hasta
        cierre.present? && record.created_at.present? && record.created_at.to_date <= cierre
      end

      # apply! crea un asiento fresco; no des-borramos el viejo (quedaría duplicado).
      def recursive_restore? = false
    end
  end
end
