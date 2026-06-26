module Restore
  module Restorers
    # CostoLote: su único efecto es entrar en el P&L del lote (se computa en lectura), así que
    # restaurar es des-borrar. Conflicto: el lote al que pertenece no debe haber sido eliminado.
    class CostoLote < Restore::Base
      def conflicts
        cs = []
        if ::Lote.where(id: record.lote_id).none?
          cs << conflict('lote_inexistente', 'El lote de este costo ya no existe (fue eliminado). Restaurá el lote primero.')
        end
        cs
      end
    end
  end
end
