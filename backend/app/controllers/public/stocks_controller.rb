module Public
  class StocksController < BaseController
    self.public_tenant_mode = :token # QR de stock es global → lookup cross-club

    def show_qr
      stock = Stock.joins(:club)
                   .where(codigo_qr: params[:codigo_qr])
                   .first

      return render json: { error: 'Producto no encontrado' }, status: :not_found unless stock

      render json: {
        id:                   stock.id,
        numero_lote_producto: stock.numero_lote_producto,
        codigo_qr:            stock.codigo_qr,
        forma_producto:       stock.forma_producto,
        unidad:               stock.unidad,
        cantidad:             stock.cantidad&.to_f,
        fecha_elaboracion:    stock.fecha_elaboracion,
        fecha_vencimiento:    stock.fecha_vencimiento_est,
        lote: stock.lote ? {
          codigo:  stock.lote.codigo,
          genetica: stock.lote.genetica ? {
            nombre:              stock.lote.genetica.nombre,
            numero_registro_inase: stock.lote.genetica.numero_registro_inase,
          } : nil,
        } : nil,
        club: {
          nombre: stock.club.name,
          logo:   stock.club.logo.attached? ? url_for(stock.club.logo) : nil,
        },
        sede: stock.sede ? { nombre: stock.sede.nombre } : nil,
      }
    end
  end
end
