module Restore
  module Restorers
    # AriccameRegistro: el estado de transmisión vive en la propia fila; restaurar es des-borrar.
    # Conflicto: si referencia una dispensación o un stock que ya no existen, el registro quedaría
    # huérfano (no se podría re-transmitir con trazabilidad), así que se bloquea.
    class AriccameRegistro < Restore::Base
      def conflicts
        cs = []
        if record.dispensacion_id && ::Dispensacion.where(id: record.dispensacion_id).none?
          cs << conflict('dispensacion_inexistente', 'La dispensación asociada a este registro ya no existe.')
        end
        if record.stock_id && ::Stock.where(id: record.stock_id).none?
          cs << conflict('stock_inexistente', 'El stock asociado a este registro ya no existe.')
        end
        cs
      end
    end
  end
end
