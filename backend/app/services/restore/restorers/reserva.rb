module Restore
  module Restorers
    # Reserva: sólo bloquea stock (vía Stock#gramos_reservados, computado de las reservas pendientes);
    # no mueve plata ni descuenta cantidad. Restaurar es des-borrar — pero si está 'pendiente' y el
    # stock ya no tiene gramos libres para cubrirla, se bloquea (no se puede re-reservar lo que no hay).
    class Reserva < Restore::Base
      def conflicts
        cs = []
        return cs unless record.estado == 'pendiente' # entregadas/canceladas/vencidas no bloquean stock

        stock = ::Stock.find_by(id: record.stock_id)
        if record.stock_id && stock.nil?
          cs << conflict('stock_inexistente', 'El stock reservado ya no existe.')
        elsif stock && stock.cantidad_disponible_real.to_d < record.cantidad.to_d
          disp = stock.cantidad_disponible_real.to_d
          cs << conflict('stock_insuficiente',
            "Stock insuficiente para re-reservar: hay #{disp.round(2)}g libres y la reserva es de #{record.cantidad}g.")
        end
        cs
      end
    end
  end
end
