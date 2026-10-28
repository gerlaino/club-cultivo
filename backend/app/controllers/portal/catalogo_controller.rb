module Portal
  # El catálogo del portal: lo que hay HOY sobre la mesa de cada sede (27-oct-2026, Germán: «un
  # catálogo de stock»). Desde el 28-oct es también «Reservar»: de acá se pide (`Portal::ReservasController`).
  #
  #   GET /portal/catalogo   por sede: los productos de la mesa, con su precio y si hay
  #
  # Lo que se publica lo decide la organización con lo que ya existe: sólo los productos de las
  # genéticas que marcó «La ve el paciente» (Configuración → Portal del paciente). Un producto sin
  # genética (una compra externa) se muestra por su forma. Nunca la cantidad exacta —eso es de la
  # operación de la organización—: «Hay», «Quedan pocos» o «No hay hoy».
  class CatalogoController < BaseController
    POCOS = { 'g' => 20, 'ml' => 50 }.freeze
    POCOS_POR_DEFECTO = 5

    def show
      data = Portal::Catalogo.por_mostrador(current_club).filter_map do |m, items|
        productos = items.map { |item| producto_json(item, m.sede_id) }
        next if productos.empty?

        { sede_id: m.sede_id, sede: m.sede&.nombre,
          productos: productos.sort_by { |p| [p[:disponibilidad] == 'no_hay' ? 1 : 0, p[:nombre].to_s] } }
      end
      render json: { data: data }
    end

    private

    def producto_json(item, sede_id)
      stock    = item.stock
      genetica = Portal::Catalogo.genetica(stock)
      {
        stock_id: stock.id,
        nombre:   genetica&.nombre || Portal::DetalleDispensa::FORMAS.fetch(stock.forma_producto, 'Producto'),
        forma:    Portal::DetalleDispensa::FORMAS.fetch(stock.forma_producto, 'Producto'),
        unidad:   stock.unidad.presence || 'g',
        # El precio que va a pagar ÉL (con su descuento), el mismo que lleva el pedido.
        precio:   stock.precio_sugerido_ars && Reserva.precio_para(stock, ficha).to_f,
        genetica: genetica && { id: genetica.id, nombre: genetica.nombre, tipo: genetica.tipo,
                                thc: genetica.thc&.to_f, cbd: genetica.cbd&.to_f },
        foto_url: foto(genetica),
        disponibilidad: disponibilidad(stock, sede_id),
      }
    end

    def ficha
      @ficha ||= current_club.pacientes.find_by(user_id: current_user.id)
    end

    # Lo LIBRE de la mesa (sin lo que ya está reservado): es contra lo que se valida un pedido, así
    # que «Hay» no puede ofrecer lo que el pedido después rechaza.
    def disponibilidad(stock, sede_id)
      cantidad = stock.libre_en_mostrador(sede_id)
      return 'no_hay' if cantidad <= 0

      cantidad < POCOS.fetch(stock.unidad.to_s, POCOS_POR_DEFECTO) ? 'pocos' : 'hay'
    end

    def foto(genetica)
      return nil unless genetica&.fotos&.attached?

      url_for(genetica.fotos.first)
    rescue StandardError
      nil
    end
  end
end
