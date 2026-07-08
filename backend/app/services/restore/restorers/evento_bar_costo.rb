module Restore
  module Restorers
    # Restaura un costo de evento re-aplicando su egreso en el libro si estaba pagado.
    class EventoBarCosto < Restore::Base
      def conflicts
        cs = []
        cs << conflict('evento_inexistente', 'El evento de este costo ya no existe.') if ::EventoBar.where(id: record.evento_bar_id).none?
        cs
      end

      private

      def apply!
        record.sincronizar_egreso
      end

      # apply! crea el egreso fresco; no des-borramos el viejo (quedaría duplicado).
      def recursive_restore? = false
    end
  end
end
