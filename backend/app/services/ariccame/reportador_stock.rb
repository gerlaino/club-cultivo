module Ariccame
  # Registra la entrada de un producto terminado (stock) en ARICCAME.
  # No hace el envío HTTP todavía — genera el registro pendiente para el job de envío.
  class ReportadorStock
    def initialize(stock)
      @stock = stock
    end

    def call
      return if ya_reportado?

      AriccameRegistro.create!(
        club:    @stock.club,
        stock:   @stock,
        tipo:    'entrada_producto',
        estado:  'pendiente',
        payload: build_payload,
      )
    end

    private

    def ya_reportado?
      AriccameRegistro.where(stock: @stock, tipo: 'entrada_producto').where.not(estado: 'error').exists?
    end

    def build_payload
      {
        numero_lote_producto: @stock.numero_lote_producto,
        codigo_qr:            @stock.codigo_qr,
        forma_producto:       @stock.forma_producto,
        unidad:               @stock.unidad,
        cantidad:             @stock.cantidad&.to_f,
        fecha_elaboracion:    @stock.fecha_elaboracion&.to_s,
        fecha_vencimiento:    @stock.fecha_vencimiento_est&.to_s,
        club_cuit:            @stock.club.cuit,
        genetica_nombre:      @stock.lote&.genetica&.nombre,
        inase_numero:         @stock.lote&.genetica&.numero_registro_inase,
        sede_nombre:          @stock.sede&.nombre,
      }
    end
  end
end
