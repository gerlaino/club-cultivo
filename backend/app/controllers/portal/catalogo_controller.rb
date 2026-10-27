module Portal
  # El catálogo del portal: lo que hay HOY sobre la mesa de cada sede (27-oct-2026, Germán: «un
  # catálogo de stock»).
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
      mostradores = Mostrador.where(club_id: current_club.id).includes(:sede).to_a.select { |m| m.sede&.activa != false }
      items = MostradorItem.where(mostrador_id: mostradores.map(&:id))
                           .includes(stock: [:genetica, { lote: :genetica }]).to_a
      por_mostrador = items.group_by(&:mostrador_id)

      data = mostradores.filter_map do |m|
        productos = Array(por_mostrador[m.id]).filter_map { |item| producto_json(item) }
        next if productos.empty?

        { sede_id: m.sede_id, sede: m.sede&.nombre,
          productos: productos.sort_by { |p| [p[:disponibilidad] == 'no_hay' ? 1 : 0, p[:nombre].to_s] } }
      end
      render json: { data: data }
    end

    private

    def producto_json(item)
      stock = item.stock
      return nil unless stock

      genetica = stock.genetica || stock.lote&.genetica
      return nil if genetica && !genetica.visible_paciente?
      return nil if item.cantidad.to_d <= 0 && !item.agotado?

      {
        stock_id: stock.id,
        nombre:   genetica&.nombre || Portal::DetalleDispensa::FORMAS.fetch(stock.forma_producto, 'Producto'),
        forma:    Portal::DetalleDispensa::FORMAS.fetch(stock.forma_producto, 'Producto'),
        unidad:   stock.unidad.presence || 'g',
        precio:   stock.precio_sugerido_ars&.to_f,
        genetica: genetica && { id: genetica.id, nombre: genetica.nombre, tipo: genetica.tipo,
                                thc: genetica.thc&.to_f, cbd: genetica.cbd&.to_f },
        foto_url: foto(genetica),
        disponibilidad: disponibilidad(item, stock),
      }
    end

    def disponibilidad(item, stock)
      cantidad = item.cantidad.to_d
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
