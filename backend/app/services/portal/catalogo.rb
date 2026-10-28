module Portal
  # Lo que el paciente ve sobre la mesa de cada sede (27-oct-2026) y, por eso mismo, lo único que
  # puede pedir desde «Reservar» (28-oct-2026). Una regla para las dos cosas: lo que no se muestra
  # no se puede pedir.
  #
  # Sólo los productos de las genéticas que la organización marcó «La ve el paciente»; uno sin
  # genética (una compra externa) se muestra por su forma.
  module Catalogo
    module_function

    # Los mostradores de las sedes activas, cada uno con sus ítems visibles: [[mostrador, [items]]].
    def por_mostrador(club)
      mostradores = Mostrador.where(club_id: club.id).includes(:sede).to_a.select { |m| m.sede&.activa != false }
      items = MostradorItem.where(mostrador_id: mostradores.map(&:id))
                           .includes(stock: [:genetica, { lote: :genetica }]).to_a
                           .select { |item| visible?(item) }
      por_id = items.group_by(&:mostrador_id)
      mostradores.map { |m| [m, Array(por_id[m.id])] }
    end

    # Los ítems visibles de la mesa de UNA sede, por stock_id.
    def de_la_sede(club, sede_id)
      m, items = por_mostrador(club).find { |mm, _| mm.sede_id == sede_id.to_i }
      m ? items.index_by(&:stock_id) : nil
    end

    def visible?(item)
      stock = item.stock
      return false unless stock

      genetica = genetica(stock)
      return false if genetica && !genetica.visible_paciente?

      item.cantidad.to_d.positive? || item.agotado?
    end

    def genetica(stock) = stock.genetica || stock.lote&.genetica
  end
end
