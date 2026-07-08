module Restore
  module Restorers
    # Restaura un evento completo: des-borra el evento con sus costos y tareas (recursivo) y
    # re-crea los egresos de los costos que estaban pagados, para que el P&L vuelva a cuadrar.
    class EventoBar < Restore::Base
      def conflicts
        cs = []
        cs << conflict('bar_inexistente', 'El bar de este evento ya no existe.') if ::Bar.where(id: record.bar_id).none?
        cs
      end

      private

      def apply!
        # Los costos volvieron con el evento (recursivo). Re-aplicamos el egreso de los pagados
        # (sus movimientos viejos se borraron al eliminar el evento).
        record.costos.reload.each(&:sincronizar_egreso)
      end

      def recursive_restore? = true
    end
  end
end
