module Mostradores
  # Corregir el conteo de un turno YA CERRADO.
  #
  # Es el único lugar del módulo donde un dedazo destruye datos: escribir 21 en vez de 215 cierra
  # con un faltante de 194 g y **ajusta el inventario real**. La caja se puede anular; esto no
  # tenía vuelta atrás.
  #
  # No se reabre el turno ni se borra nada: el ajuste viejo queda y se asienta **la diferencia
  # entre lo que se había contado y lo que se cuenta ahora**. Borrar un movimiento de stock para
  # tapar un error es peor que el error — el rastro de que alguien corrigió es justamente lo que
  # hay que poder mostrar después.
  #
  # Corrige administración, no el mostrador: toca inventario de un turno que ya cerró.
  class CorregirCierre
    Result = Struct.new(:ok, :turno, :error, keyword_init: true) do
      def ok? = ok
    end

    def self.call(**kwargs) = new(**kwargs).call

    # `conteos`: [{ item_id:, contado: }] — sólo los que haya que corregir.
    def initialize(turno:, usuario:, conteos: [], motivo: nil)
      @turno   = turno
      @usuario = usuario
      @conteos = Array(conteos).select { |c| c.respond_to?(:[]) && !c.is_a?(String) }
      @motivo  = motivo
    end

    def call
      return err('El turno no está cerrado') unless @turno&.cerrado?
      return err('Escribí por qué se corrige el conteo') if @motivo.blank?
      return err('No hay nada que corregir') if @conteos.empty?

      ActiveRecord::Base.transaction { @conteos.each { |c| corregir!(c) } }
      Result.new(ok: true, turno: @turno.reload)
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      err(e.message)
    end

    private

    def err(msg) = Result.new(ok: false, error: msg)

    def corregir!(datos)
      item = @turno.items.find_by(id: (datos[:item_id] || datos['item_id']))
      raise ArgumentError, 'Ese producto no está en el turno' if item.nil?

      nuevo = (datos[:contado] || datos['contado']).to_d
      raise ArgumentError, 'La cantidad contada no puede ser negativa' if nuevo.negative?

      delta = nuevo - item.cantidad_cierre.to_d
      return if delta.zero?

      stock = item.stock
      raise ArgumentError, 'El producto ya no existe' if stock.nil?

      item.update!(cantidad_cierre: nuevo,
                   motivo_diferencia: [item.motivo_diferencia, "corregido: #{@motivo}"].compact.join(' · '))

      stock.with_lock do
        stock.update!(cantidad: [stock.cantidad.to_d + delta, 0].max)
        stock.stock_movimientos.create!(
          tipo: 'ajuste', gramos: delta, usuario: @usuario, turno_mostrador: @turno,
          notas: "Corrección del conteo del turno ##{@turno.id} — se había contado " \
                 "#{(nuevo - delta).to_f} y eran #{nuevo.to_f} #{stock.unidad || 'g'} — #{@motivo}"
        )
      end
      stock.reload.marcar_agotado_si_vacio!(usuario: @usuario)
    end
  end
end
