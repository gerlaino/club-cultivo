module Mostradores
  # CONTAR UN PRODUCTO SIN CERRAR LA CAJA.
  #
  # Cerrar y reabrir sigue siendo el arqueo completo, pero con quince frascos son veinte minutos:
  # un control que cuesta eso no se hace dos veces por día, y el que no se hace no controla nada.
  #
  # A diferencia del conteo de APERTURA —que sólo corre el punto de partida, porque ahí todavía
  # puede ser que la mesa se haya cargado de más y el producto esté en el depósito— acá la
  # diferencia SÍ ajusta el inventario: el producto estaba sobre la mesa, se contó, y no está.
  #
  # Y por eso el motivo es obligatorio: un faltante sin explicación no se puede revisar después, y
  # a los tres días nadie se acuerda.
  class Contar
    Result = Struct.new(:ok, :item, :diferencia, :error, keyword_init: true) do
      def ok? = ok
    end

    def self.call(**kwargs) = new(**kwargs).call

    def initialize(mostrador:, usuario:, stock_id:, contado:, motivo: nil)
      @mostrador = mostrador
      @usuario   = usuario
      @stock_id  = stock_id
      @contado   = contado
      @motivo    = motivo
    end

    def call
      item = @mostrador.items.find_by(stock_id: @stock_id)
      return err('Ese producto no está sobre la mesa') if item.nil?

      contado = @contado.to_d
      return err('La cantidad contada no puede ser negativa') if contado.negative?

      dif = contado - item.cantidad.to_d
      return Result.new(ok: true, item: item, diferencia: 0.to_d) if dif.zero?
      return err('Hay diferencia: escribí el motivo') if @motivo.blank?

      turno = @mostrador.turno_abierto
      ActiveRecord::Base.transaction do
        item.mover!(cantidad: dif, tipo: 'ajuste', usuario: @usuario, turno: turno,
                    motivo: "Conteo — #{@motivo}")
        item.ajustar_inventario!(dif, usuario: @usuario, turno: turno,
                                 concepto: 'Conteo del mostrador', notas: @motivo)
      end
      Result.new(ok: true, item: item, diferencia: dif)
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      err(e.message)
    end

    private

    def err(msg) = Result.new(ok: false, error: msg)
  end
end
