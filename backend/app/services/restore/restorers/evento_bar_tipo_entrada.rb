module Restore
  module Restorers
    # Restaura un tipo de entrada con sus entradas y re-crea su ingreso agregado en el libro.
    class EventoBarTipoEntrada < Restore::Base
      def conflicts
        cs = []
        cs << conflict('evento_inexistente', 'El evento de este tipo de entrada ya no existe.') if ::EventoBar.where(id: record.evento_bar_id).none?
        cs
      end

      private

      def apply!
        actor = usuario || record.deleted_by || record.club.users.find_by(role: 'admin')
        # Las entradas vuelven con el tipo (son estructura); luego se re-agrega el ingreso.
        record.entradas.with_deleted.where.not(deleted_at: nil).each(&:restore)
        record.sincronizar_ingreso!(actor)
      end

      def recursive_restore? = false
    end
  end
end
