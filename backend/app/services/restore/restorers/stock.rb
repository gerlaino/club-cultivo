module Restore
  module Restorers
    # Stock: restaurar re-incorpora la partida con su cantidad y sus movimientos (recursive). Si el
    # lote se finalizó porque su stock se había agotado, reabrirlo a 'curado' (deja de ser cierto que
    # no queda stock). Conflicto: la sede o el lote de origen no deben haber sido eliminados.
    class Stock < Restore::Base
      def conflicts
        cs = []
        if record.sede_id && ::Sede.where(id: record.sede_id).none?
          cs << conflict('sede_inexistente', 'La sede de este stock ya no existe.')
        end
        if record.lote_id && ::Lote.where(id: record.lote_id).none?
          cs << conflict('lote_inexistente', 'El lote de origen de este stock ya no existe.')
        end
        cs
      end

      private

      def apply!
        reabrir_lote_si_corresponde
      end

      def reabrir_lote_si_corresponde
        return if record.estado == 'agotado' # un stock agotado no contradice la finalización
        lote = ::Lote.find_by(id: record.lote_id)
        return unless lote&.estado == 'finalizado'

        actor = usuario || record.deleted_by || lote.club.users.find_by(role: 'admin')
        lote.update!(estado: 'curado')
        lote.lote_eventos.create!(
          tipo: 'cambio_estado', estado_anterior: 'finalizado', estado_nuevo: 'curado',
          descripcion: 'Stock restaurado — lote reabierto a curado.',
          user: actor, club: lote.club, registrado_en: Time.current,
        )
      end
    end
  end
end
