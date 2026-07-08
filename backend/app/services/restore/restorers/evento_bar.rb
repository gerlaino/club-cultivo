module Restore
  module Restorers
    # Restaura un evento completo: des-borra el evento con sus costos y tareas (recursivo) y
    # re-crea los egresos de los costos que estaban pagados, para que el P&L vuelva a cuadrar.
    class EventoBar < Restore::Base
      def conflicts
        cs = []
        cs << conflict('bar_inexistente', 'El bar de este evento ya no existe.') if ::Barra.where(id: record.bar_id).none?
        cs
      end

      private

      def apply!
        actor = usuario || record.deleted_by || record.club.users.find_by(role: 'admin')
        # Costos y tipos de entrada volvieron con el evento (recursivo). Re-aplicamos sus efectos
        # en el libro (los movimientos viejos se borraron al eliminar el evento).
        record.costos.reload.each(&:sincronizar_egreso)
        record.tipos_entrada.reload.each do |t|
          t.entradas.with_deleted.where.not(deleted_at: nil).each(&:restore)
          t.sincronizar_ingreso!(actor)
        end
      end

      def recursive_restore? = true
    end
  end
end
